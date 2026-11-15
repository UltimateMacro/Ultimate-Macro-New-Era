using System.Buffers.Binary;
using System.Globalization;
using System.IO.Compression;
using System.Net;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.RegularExpressions;

internal static class Program
{
    const string Feed = "https://keys.ultmacro.xyz/keys/ahk-updates-v2/";
    const string Channel = "ahk-stable";
    static readonly Version MinimumVersion = new(1, 4, 0, 32);
    const long Limit = 256L * 1024 * 1024;
    const string PublicKey = """
        -----BEGIN PUBLIC KEY-----
        MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAzFGAsqEIOEvHNqRc/T/i
        AWpr6j2Nh1OuQfMw9P2ZHCUf7D3wiFt5qsutZI/o0ZOui5Jlzb/bbJnvUlxvjZLh
        PSSizZYzAshhhXDljK5yADk0Xj6tEDGWcEp6JXEmpv/+uBx3+H1bye1F+Ox5ZY42
        FRNvWQXzuSYfKziapQstSKx1wngbfbNjO+ZJX1QEG1OEGdjZ9SrAhXj/DMojk+2E
        /c07srLx7qY6MzxJKb8QTSuemIEWfiu0xXBYVaCCUpiOYTz6CuqsP5QXbd+irJ4N
        XCPB/yWaMGInzO+45IQzsQ2lEzTpw/RHmybtjYRacDjByIgTCjoztnR+tM9sLFM5
        fVYB8ZR+qD+1pej4knUP4YQjkETbnYDGuBy7ggYOFM3c42uIOq+nl8uOqvGXlKHc
        XOqlW/rolPGuw5LqDr7l9QxgzRFldvalRWCxHfnD5JHJkTA+28SjbkQ8M5avAJx2
        6+hRanGLkHXDcNg+oJnTjZ7ptiqwSl3ovsS8uKSSJ9UdHOyv2fUGxC/kQpjD+N7P
        9jfhbKIaoAtVZ/nbfJUzVt7M9GV98EStYXUXNj34rSqeBe//De7m0sRdI4vPgdCR
        fMHnfmlTYFQ+xJPqMZg2ikFTtpNx26AV+eUfKB9EzkqegZvUDKbBQSO2vGPOPMhP
        Mk3JGybL4wqJirK8K3A2QV0CAwEAAQ==
        -----END PUBLIC KEY-----
        """;
    const string KeyHash = "A79A3B30F06178C992EC7F87DCFF44DDE2E5481501637CC30FD2A0A7451D88B9";
    static readonly Regex VersionPattern = new(@"\A1\.4\.(?:0|[1-9][0-9]{0,4})\.(?:0|[1-9][0-9]{0,4})\z");
    static readonly Regex TimePattern = new(@"\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]{1,7})?(?:Z|[+-][0-9]{2}:[0-9]{2})\z");
    static readonly string[] Fields = ["Version", "Channel", "Url", "Sha256", "Bytes", "IssuedAt", "ExpiresAt"];

    internal record Offer(Version Version, string Url, byte[] Digest, long Bytes, DateTimeOffset Expires);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern int MessageBoxW(nint parent, string text, string title, uint flags);

    static async Task<int> Main(string[] args)
    {
        try
        {
            using var rsa = RSA.Create();
            rsa.ImportFromPem(PublicKey);
            if (rsa.KeySize != 4096 || Convert.ToHexString(SHA256.HashData(rsa.ExportSubjectPublicKeyInfo())) != KeyHash)
                throw new InvalidDataException();
            if (args is ["--self-test"])
                return SelfTest();
            if (args is ["--self-test-package", var candidate])
                return SelfTestPackage(candidate).GetAwaiter().GetResult();
            if (args is ["--check-layout", var archiveFile])
            {
                using var archive = ZipFile.OpenRead(archiveFile);
                ValidateArchive(archive);
                Console.WriteLine($"PASS: archive layout ({archive.Entries.Count} files); signature not checked.");
                return 0;
            }
            if (args.Length != 2 || !VersionPattern.IsMatch(args[0]) || args[1] is not ("stage" or "review"))
                return 10;
            var review = args[1] == "review";
            var requested = Version.Parse(args[0]);
            var installed = requested > MinimumVersion ? requested : MinimumVersion;
            using var handler = new HttpClientHandler { AllowAutoRedirect = false, UseCookies = false, UseDefaultCredentials = false };
            using var http = new HttpClient(handler);
            var local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            if (string.IsNullOrEmpty(local))
                throw new InvalidDataException();
            var appFolder = EnsureFolder(Path.Combine(local, "UltimateMacro14AHK"));
            var folder = EnsureFolder(Path.Combine(appFolder, "VerifiedUpdatesV2"));
            return await RunUpdate(http, rsa, installed, review, folder, (offer, install) =>
                MessageBoxW(0, $"AHK update {offer.Version}\n\nSHA-256: {Convert.ToHexString(offer.Digest)}\nZIP size: {offer.Bytes:N0} bytes\n\nInstall to a new folder?\n{install}\n\nYour current copy stays in place. Nothing will close or launch automatically.",
                    "Ultimate Macro — verified update", 0x124) == 6, () => DateTimeOffset.UtcNow);
        }
        catch (HttpRequestException e) when (e.StatusCode == HttpStatusCode.NotFound) { return 4; }
        catch (Exception e) when (e is IOException or InvalidDataException or UnauthorizedAccessException or HttpRequestException
            or JsonException or CryptographicException or OperationCanceledException or ArgumentException or InvalidOperationException or FormatException) { return 10; }
    }

    internal static async Task<int> RunUpdate(HttpClient http, RSA trust, Version installed, bool review, string folder,
        Func<Offer, string, bool> approve, Func<DateTimeOffset> clock)
    {
        var lockPath = Path.Combine(folder, ".updater.lock");
        RequireOrdinary(lockPath, false);
        using var single = new FileStream(lockPath, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
        using var metadataDeadline = new CancellationTokenSource(TimeSpan.FromMinutes(2));
        var (raw, sig, offer) = await GetVerifiedOffer(http, trust, clock, metadataDeadline.Token);
        var floorPath = Path.Combine(folder, ".highest-offer");
        var highest = ReadFloor(floorPath, trust, clock());
        if (offer.Version < installed || highest is not null && offer.Version < highest.Version)
            return 11;
        if (highest is not null && offer.Version == highest.Version
            && (highest.Bytes != offer.Bytes || !CryptographicOperations.FixedTimeEquals(highest.Digest, offer.Digest)))
            throw new InvalidDataException("Release version reused for different contents.");
        if (offer.Version == installed)
            return 2;
        if (highest is null || offer.Version > highest.Version)
            SaveFloor(floorPath, raw, sig);

        var name = $"UltimateMacro-AHK-{offer.Version}";
        var target = Path.Combine(folder, name + ".zip");
        var cached = await OpenVerified(target, offer);
        if (cached is null)
        {
            await Download(http, offer, target, replace: true);
            cached = await OpenVerified(target, offer) ?? throw new InvalidDataException("Staging did not produce a valid package.");
        }
        // Keep the original verified file open and immutable through consent and extraction.
        await using var saved = cached;
        using (var archive = new ZipArchive(saved, ZipArchiveMode.Read, leaveOpen: true))
            ValidateArchive(archive);
        if (!review)
            return 6;
        var install = Path.Combine(folder, name);
        RequireOrdinary(install, true);
        if (Directory.Exists(install))
            return 8;
        if (clock() >= offer.Expires || !approve(offer, install))
            return 3;
        if (clock() >= offer.Expires)
            throw new InvalidDataException("The offer expired during approval.");
        saved.Position = 0;
        ExtractVerified(saved, install);
        return 0;
    }

    static void RequireOrdinary(string path, bool directory)
    {
        FileAttributes attributes;
        try { attributes = File.GetAttributes(path); }
        catch (Exception error) when (error is FileNotFoundException or DirectoryNotFoundException) { return; }
        if ((attributes & FileAttributes.ReparsePoint) != 0 || attributes.HasFlag(FileAttributes.Directory) != directory)
            throw new InvalidDataException("Unexpected update storage path type.");
    }

    static string EnsureFolder(string folder)
    {
        RequireOrdinary(folder, true);
        Directory.CreateDirectory(folder);
        RequireOrdinary(folder, true);
        return folder;
    }

    static Offer? ReadFloor(string path, RSA trust, DateTimeOffset now)
    {
        RequireOrdinary(path, false);
        if (!File.Exists(path))
            return null;
        using var input = File.OpenRead(path);
        if (input.Length is < 5 or > 16900)
            throw new InvalidDataException();
        var data = new byte[(int)input.Length];
        input.ReadExactly(data);
        int size = BinaryPrimitives.ReadInt32LittleEndian(data);
        if (size <= 0 || size > 16384 || data.Length - 4 - size != trust.KeySize / 8)
            throw new InvalidDataException();
        return Parse(data[4..(4 + size)], data[(4 + size)..], trust, now, retained: true);
    }

    static void SaveFloor(string path, byte[] raw, byte[] sig)
    {
        var temp = Path.Combine(Path.GetDirectoryName(path)!, $".proof-{Guid.NewGuid():N}");
        var prefix = new byte[4];
        BinaryPrimitives.WriteInt32LittleEndian(prefix, raw.Length);
        using (var output = new FileStream(temp, FileMode.CreateNew, FileAccess.Write, FileShare.None))
        {
            output.Write(prefix);
            output.Write(raw);
            output.Write(sig);
            output.Flush(true);
        }
        try { File.Move(temp, path, overwrite: true); }
        finally { try { File.Delete(temp); } catch (IOException) { } }
    }

    static async Task<FileStream?> OpenVerified(string target, Offer offer)
    {
        RequireOrdinary(target, false);
        if (!File.Exists(target))
            return null;
        var saved = new FileStream(target, FileMode.Open, FileAccess.Read, FileShare.Read);
        try
        {
            using var deadline = new CancellationTokenSource(TimeSpan.FromMinutes(2));
            await VerifyCopy(saved, Stream.Null, offer, deadline.Token);
            saved.Position = 0;
            return saved;
        }
        catch (InvalidDataException) { await saved.DisposeAsync(); return null; }
        catch { await saved.DisposeAsync(); throw; }
    }

    static async Task Download(HttpClient http, Offer offer, string target, bool replace = false)
    {
        using var deadline = new CancellationTokenSource(TimeSpan.FromMinutes(8));
        var temp = Path.Combine(Path.GetDirectoryName(target)!, $".download-{Guid.NewGuid():N}");
        var created = false;
        try
        {
            using var response = await Fetch(http, offer.Url, deadline.Token);
            await using var input = await response.Content.ReadAsStreamAsync(deadline.Token);
            await using (var output = new FileStream(temp, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            {
                created = true;
                await VerifyCopy(input, output, offer, deadline.Token);
            }
            RequireOrdinary(target, false);
            File.Move(temp, target, replace);
        }
        finally { if (created) try { File.Delete(temp); } catch (IOException) { } }
    }

    static readonly Regex Part = new(@"\A[A-Za-z0-9 _!+().,-]{1,120}\z");
    static readonly Regex Device = new(@"\A(?:CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(?:\.|\z)", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

    internal static void ExtractVerified(Stream input, string target)
    {
        using var zip = new ZipArchive(input, ZipArchiveMode.Read, true);
        ValidateArchive(zip);
        if (Path.Exists(target))
            throw new InvalidDataException();
        var stage = Path.Combine(Path.GetDirectoryName(target)!, $".install-{Guid.NewGuid():N}");
        Directory.CreateDirectory(stage);
        try
        {
            var buffer = new byte[65536];
            foreach (var entry in zip.Entries)
            {
                var path = Path.Combine(stage, entry.FullName);
                Directory.CreateDirectory(Path.GetDirectoryName(path)!);
                using var from = entry.Open();
                using var to = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None);
                long left = entry.Length;
                while (left > 0)
                {
                    var n = from.Read(buffer, 0, (int)Math.Min(left, buffer.Length));
                    if (n == 0) throw new InvalidDataException();
                    to.Write(buffer, 0, n);
                    left -= n;
                }
                if (from.ReadByte() != -1)
                    throw new InvalidDataException();
            }
            Directory.Move(stage, target);
        }
        finally { if (Directory.Exists(stage)) Directory.Delete(stage, true); }
    }

    static void ValidateArchive(ZipArchive zip)
    {
        if (zip.Entries.Count is 0 or > 4096)
            throw new InvalidDataException();
        const long expandedLimit = 512L * 1024 * 1024;
        long expanded = 0;
        var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var entry in zip.Entries)
        {
            var parts = entry.FullName.Split('/');
            if (parts.Length > 12 || entry.FullName.Length > 220 || !names.Add(entry.FullName)
                || parts.Any(p => !Part.IsMatch(p) || p[0] == ' ' || p.EndsWith('.') || p.EndsWith(' ') || Device.IsMatch(p))
                || ((entry.ExternalAttributes >> 16) & 0xf000) is not (0 or 0x8000)
                || (entry.ExternalAttributes & 0x410) != 0
                || (expanded += entry.Length) > expandedLimit)
                throw new InvalidDataException();
        }
        foreach (var name in names)
            for (var slash = name.IndexOf('/'); slash >= 0; slash = name.IndexOf('/', slash + 1))
                if (names.Contains(name[..slash]))
                    throw new InvalidDataException("A package path is both a file and a directory.");
        foreach (var required in new[] { "Main.ahk", "app/Updater.ahk", "engine/UM14Engine.ahk", "updater/UltimateMacro.AhkUpdater.exe" })
            if (zip.GetEntry(required) is null)
                throw new InvalidDataException();
    }

    static async Task<HttpResponseMessage> Fetch(HttpClient http, string url, CancellationToken stop)
    {
        var response = await http.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, stop);
        if (response.StatusCode == HttpStatusCode.OK)
            return response;
        var code = response.StatusCode;
        response.Dispose();
        throw new HttpRequestException("Unexpected update status.", null, code);
    }

    static async Task<byte[]> GetSmall(HttpClient http, string url, int max, CancellationToken stop)
    {
        using var response = await Fetch(http, url, stop);
        await using var input = await response.Content.ReadAsStreamAsync(stop);
        var bytes = new byte[max + 1];
        int count = await input.ReadAtLeastAsync(bytes, bytes.Length, false, stop);
        if (count is 0 || count > max)
            throw new InvalidDataException();
        return bytes[..count];
    }

    static async Task<(byte[] Raw, byte[] Signature, Offer Release)> GetVerifiedOffer(
        HttpClient http, RSA trust, Func<DateTimeOffset> clock, CancellationToken stop)
    {
        for (int read = 0; ; read++)
        {
            var raw = await GetSmall(http, Feed + "stable.json", 16384, stop);
            var sig = await GetSmall(http, Feed + "stable.sig", 512, stop);
            // The atomic server switch can occur between these two GETs.
            // Retry the whole pair once; only a valid signature can proceed.
            if (read == 0 && sig.Length == trust.KeySize / 8
                && !trust.VerifyData(raw, sig, HashAlgorithmName.SHA256, RSASignaturePadding.Pss))
                continue;
            return (raw, sig, Parse(raw, sig, trust, clock()));
        }
    }

    static DateTimeOffset Time(string? value)
    {
        if (value is null || !TimePattern.IsMatch(value)
            || !DateTimeOffset.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsed))
            throw new InvalidDataException();
        return parsed;
    }

    internal static Offer Parse(byte[] raw, byte[] signature, RSA trusted, DateTimeOffset now, bool retained = false)
    {
        if (raw.Length is 0 or > 16384 || signature.Length != trusted.KeySize / 8
            || !trusted.VerifyData(raw, signature, HashAlgorithmName.SHA256, RSASignaturePadding.Pss))
            throw new InvalidDataException();
        using var document = JsonDocument.Parse(raw, new JsonDocumentOptions { MaxDepth = 4 });
        var json = document.RootElement;
        var fields = new HashSet<string>(Fields, StringComparer.Ordinal);
        if (json.ValueKind != JsonValueKind.Object || json.EnumerateObject().Any(p => !fields.Remove(p.Name)) || fields.Count != 0)
            throw new InvalidDataException();
        string? version = json.GetProperty("Version").GetString(), hash = json.GetProperty("Sha256").GetString();
        var issued = Time(json.GetProperty("IssuedAt").GetString());
        var expiry = Time(json.GetProperty("ExpiresAt").GetString());
        var bytes = json.GetProperty("Bytes").GetInt64();
        if (version is null || !VersionPattern.IsMatch(version) || json.GetProperty("Channel").GetString() != Channel
            || json.GetProperty("Url").GetString() != Feed + version + ".zip"
            || hash is null || !Regex.IsMatch(hash, @"\A[0-9a-fA-F]{64}\z") || bytes is <= 0 or > Limit
            || (!retained && (issued > now.AddMinutes(5) || expiry <= now))
            || expiry <= issued || expiry - issued > TimeSpan.FromDays(14))
            throw new InvalidDataException();
        return new(Version.Parse(version), Feed + version + ".zip", Convert.FromHexString(hash), bytes, expiry);
    }

    internal static async Task VerifyCopy(Stream input, Stream output, Offer offer, CancellationToken stop)
    {
        using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        var buffer = new byte[65536];
        long total = 0;
        for (int n; (n = await input.ReadAsync(buffer, stop)) != 0;)
        {
            total += n;
            if (total > offer.Bytes || total > Limit)
                throw new InvalidDataException();
            hash.AppendData(buffer, 0, n);
            await output.WriteAsync(buffer.AsMemory(0, n), stop);
        }
        if (total != offer.Bytes || !CryptographicOperations.FixedTimeEquals(hash.GetHashAndReset(), offer.Digest))
            throw new InvalidDataException();
    }

    static byte[] FixtureManifest(Dictionary<string, object> fields)
    {
        using var bytes = new MemoryStream();
        using (var json = new Utf8JsonWriter(bytes))
        {
            json.WriteStartObject();
            foreach (var (name, value) in fields)
            {
                switch (value)
                {
                    case string text: json.WriteString(name, text); break;
                    case int number: json.WriteNumber(name, number); break;
                    case long number: json.WriteNumber(name, number); break;
                    case DateTimeOffset time: json.WriteString(name, time); break;
                    default: throw new InvalidOperationException("Unexpected fixture value.");
                }
            }
            json.WriteEndObject();
        }
        return bytes.ToArray();
    }

    static int SelfTest()
    {
        using var key = RSA.Create(3072);
        using var other = RSA.Create(3072);
        var now = DateTimeOffset.UtcNow;
        byte[] sample = [42, 43, 44];
        const string version = "1.4.0.30";
        var data = new Dictionary<string, object> {
            ["Version"] = version, ["Channel"] = Channel, ["Url"] = Feed + version + ".zip",
            ["Sha256"] = Convert.ToHexString(SHA256.HashData(sample)), ["Bytes"] = sample.Length,
            ["IssuedAt"] = now, ["ExpiresAt"] = now.AddDays(1)
        };
        var raw = FixtureManifest(data);
        byte[] Sign(byte[] b) => key.SignData(b, HashAlgorithmName.SHA256, RSASignaturePadding.Pss);
        var offer = Parse(raw, Sign(raw), key, now);
        VerifyCopy(new MemoryStream(sample), Stream.Null, offer, default).GetAwaiter().GetResult();
        void Refused(Action check)
        {
            try { check(); }
            catch (InvalidDataException) { return; }
            throw new InvalidOperationException("Unexpected acceptance");
        }
        Refused(() => Parse(raw, Sign(raw), other, now));
        Refused(() => Parse(raw, Sign(raw), key, now.AddDays(2)));
        using (var http = new HttpClient(new FeedFixture(raw, Sign(raw), sample, new byte[384])))
        {
            var raced = GetVerifiedOffer(http, key, () => now, default).GetAwaiter().GetResult();
            if (raced.Release.Version != offer.Version)
                throw new InvalidOperationException("Incorrect release after publication raced the metadata GETs.");
        }
        using (var http = new HttpClient(new FeedFixture(raw, new byte[384], sample)))
            Refused(() => GetVerifiedOffer(http, key, () => now, default).GetAwaiter().GetResult());
        Refused(() => VerifyCopy(new MemoryStream([42, 43, 45]), Stream.Null, offer, default).GetAwaiter().GetResult());
        Refused(() => VerifyCopy(new MemoryStream([42, 43, 44, 45]), Stream.Null, offer, default).GetAwaiter().GetResult());
        foreach (var (field, value) in new (string, object)[] {
            ("Channel", "stable"), ("Url", Feed + version + ".zip?x=1"), ("Bytes", Limit + 1), ("Version", "1.4.00.30")
        })
        {
            var changed = new Dictionary<string, object>(data) { [field] = value };
            var payload = FixtureManifest(changed);
            Refused(() => Parse(payload, Sign(payload), key, now));
        }
        MemoryStream Fixture(params string[] extra)
        {
            var memory = new MemoryStream();
            using (var archive = new ZipArchive(memory, ZipArchiveMode.Create, true))
                foreach (var name in new[] { "Main.ahk", "app/Updater.ahk", "engine/UM14Engine.ahk", "updater/UltimateMacro.AhkUpdater.exe" }.Concat(extra))
                    using (var entry = archive.CreateEntry(name).Open()) entry.Write(sample);
            memory.Position = 0;
            return memory;
        }
        var root = Directory.CreateTempSubdirectory("um-ahk-qa-");
        try
        {
            var destination = Path.Combine(root.FullName, "installed");
            foreach (var invalid in new[] { "../outside", "engine/../escape", "C:/absolute", "CON.txt", "Main.AHK", "file.txt:stream", "folder/", "APP" })
                Refused(() => { using var zip = Fixture(invalid); ExtractVerified(zip, destination); });
            if (Directory.EnumerateFileSystemEntries(root.FullName).Any())
                throw new InvalidOperationException("Invalid archives wrote files");
            using (var zip = Fixture())
            {
                var bytes = zip.ToArray();
                var download = offer with { Bytes = bytes.Length, Digest = SHA256.HashData(bytes) };
                using var http = new HttpClient(new FixtureHandler(bytes));
                var cached = Path.Combine(root.FullName, "pending.zip");
                Download(http, download, cached).GetAwaiter().GetResult();
                if (Directory.Exists(destination) || !File.ReadAllBytes(cached).SequenceEqual(bytes))
                    throw new InvalidOperationException("Quiet download installed or changed the package");
                var corrupt = Path.Combine(root.FullName, "corrupt.zip");
                Refused(() => Download(http, download with { Digest = new byte[32] }, corrupt).GetAwaiter().GetResult());
                if (File.Exists(corrupt) || Directory.EnumerateFiles(root.FullName, ".download-*").Any())
                    throw new InvalidOperationException("Failed download left unverified bytes");
            }
            using (var zip = Fixture()) ExtractVerified(zip, destination);
            if (!File.ReadAllBytes(Path.Combine(destination, "Main.ahk")).SequenceEqual(sample))
                throw new InvalidOperationException("Installed contents differ");
            Refused(() => { using var zip = Fixture(); ExtractVerified(zip, destination); });
            var updateFolder = EnsureFolder(Path.Combine(root.FullName, "flow"));
            using var releaseZip = Fixture();
            var releaseBytes = releaseZip.ToArray();
            using var otherZip = Fixture("another.txt");
            var otherBytes = otherZip.ToArray();
            var nowForFlow = now;
            var approvalCalls = 0;
            int Flow(string offered, byte[] payload, bool review, bool allow, bool expireOnApproval = false)
            {
                var body = FixtureManifest(new Dictionary<string, object>(data)
                {
                    ["Version"] = offered, ["Url"] = Feed + offered + ".zip", ["Bytes"] = payload.Length,
                    ["Sha256"] = Convert.ToHexString(SHA256.HashData(payload)),
                    ["IssuedAt"] = nowForFlow, ["ExpiresAt"] = nowForFlow.AddDays(1)
                });
                using var http = new HttpClient(new FeedFixture(body, Sign(body), payload));
                return RunUpdate(http, key, new Version(1, 4, 0, 32), review, updateFolder,
                    (_, _) =>
                    {
                        approvalCalls++;
                        if (expireOnApproval)
                            nowForFlow = nowForFlow.AddDays(2);
                        return allow;
                    }, () => nowForFlow).GetAwaiter().GetResult();
            }
            var zip34 = Path.Combine(updateFolder, "UltimateMacro-AHK-1.4.0.34.zip");
            var installed34 = Path.Combine(updateFolder, "UltimateMacro-AHK-1.4.0.34");
            if (Flow("1.4.0.34", releaseBytes, false, true) != 6 || approvalCalls != 0 || Directory.Exists(installed34))
                throw new InvalidOperationException("Silent update asked for consent or installed.");
            File.WriteAllBytes(zip34, [1, 2, 3]);
            if (Flow("1.4.0.34", releaseBytes, true, false) != 3 || approvalCalls != 1 || Directory.Exists(installed34)
                || !File.ReadAllBytes(zip34).SequenceEqual(releaseBytes))
                throw new InvalidOperationException("Decline or cache recovery failed.");
            Refused(() => Flow("1.4.0.34", otherBytes, true, true));
            Refused(() => Flow("1.4.0.34", releaseBytes, true, true, expireOnApproval: true));
            if (Directory.Exists(installed34) || Flow("1.4.0.33", releaseBytes, true, true) != 11 || approvalCalls != 2)
                throw new InvalidOperationException("Expired approval or replay was accepted.");
            if (Flow("1.4.0.34", releaseBytes, true, true) != 0 || approvalCalls != 3
                || !File.ReadAllBytes(Path.Combine(installed34, "Main.ahk")).SequenceEqual(sample))
                throw new InvalidOperationException("Approved installation failed.");
            using var invalidZip = Fixture("../not-an-update");
            Refused(() => Flow("1.4.0.35", invalidZip.ToArray(), false, true));
            if (approvalCalls != 3 || Directory.Exists(Path.Combine(updateFolder, "UltimateMacro-AHK-1.4.0.35")))
                throw new InvalidOperationException("Signed malformed archive offered for install.");
        }
        finally { root.Delete(true); }
        Console.WriteLine("PASS: signed manifest, publication-race retry, quiet staging, cache repair, approval/decline, expired approval, rollback, same-version substitution and safe ZIP extraction.");
        return 0;
    }

    static async Task<int> SelfTestPackage(string candidate)
    {
        var archive = new FileInfo(candidate);
        if (archive.Length is <= 0 or > Limit)
            throw new InvalidDataException();
        var payload = File.ReadAllBytes(archive.FullName);
        using var zip = new ZipArchive(new MemoryStream(payload, false), ZipArchiveMode.Read);
        ValidateArchive(zip);

        using var key = RSA.Create(4096);
        var now = DateTimeOffset.UtcNow;
        const string version = "1.4.0.35";
        var body = FixtureManifest(new Dictionary<string, object>
        {
            ["Version"] = version, ["Channel"] = Channel, ["Url"] = Feed + version + ".zip",
            ["Sha256"] = Convert.ToHexString(SHA256.HashData(payload)), ["Bytes"] = payload.Length,
            ["IssuedAt"] = now, ["ExpiresAt"] = now.AddDays(1)
        });
        var sig = key.SignData(body, HashAlgorithmName.SHA256, RSASignaturePadding.Pss);
        var root = Directory.CreateTempSubdirectory("um-ahk-package-qa-");
        try
        {
            using var http = new HttpClient(new FeedFixture(body, sig, payload));
            var target = Path.Combine(root.FullName, "UltimateMacro-AHK-" + version);
            var installed = new Version(1, 4, 0, 34);
            var approvals = 0;
            Task<int> Run(bool review, bool confirm) => RunUpdate(http, key, installed, review, root.FullName,
                (_, path) =>
                {
                    if (path != target)
                        throw new InvalidDataException("Wrong installation target.");
                    approvals++;
                    return confirm;
                }, () => now);
            if (await Run(false, true) != 6 || approvals != 0 || Directory.Exists(target)
                || await Run(true, false) != 3 || approvals != 1 || Directory.Exists(target)
                || await Run(true, true) != 0 || approvals != 2)
                throw new InvalidOperationException("Package staging or explicit approval failed.");

            foreach (var entry in zip.Entries)
            {
                using var original = entry.Open();
                using var extracted = File.OpenRead(Path.Combine(target, entry.FullName));
                if (!CryptographicOperations.FixedTimeEquals(SHA256.HashData(original), SHA256.HashData(extracted)))
                    throw new InvalidDataException("Installed file differs from the verified archive.");
            }
            if (await Run(true, true) != 8 || approvals != 2)
                throw new InvalidOperationException("Second update tried to replace an existing version.");
        }
        finally { root.Delete(true); }
        Console.WriteLine($"PASS: exact ZIP ({zip.Entries.Count} files), test signature, quiet download, decline, approved extraction and no overwrite.");
        return 0;
    }

    sealed class FixtureHandler(byte[] bytes) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
            => Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new ByteArrayContent(bytes) });
    }
    sealed class FeedFixture(byte[] manifest, byte[] signature, byte[] archive, byte[]? firstSignature = null) : HttpMessageHandler
    {
        int signatureReads;

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var uri = request.RequestUri?.AbsoluteUri;
            var content = uri switch
            {
                Feed + "stable.json" => manifest,
                Feed + "stable.sig" => Interlocked.Increment(ref signatureReads) == 1 && firstSignature != null ? firstSignature : signature,
                _ when uri?.StartsWith(Feed, StringComparison.Ordinal) == true && uri.EndsWith(".zip", StringComparison.Ordinal) => archive,
                _ => throw new InvalidOperationException("Unexpected update request.")
            };
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new ByteArrayContent(content) });
        }
    }
}
