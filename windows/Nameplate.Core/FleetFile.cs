using System.Text.Json;
using System.Text.Json.Serialization;

namespace Nameplate.Core;

public sealed record FleetEntry
{
    [JsonPropertyName("name")]
    public string? Name { get; init; }

    [JsonPropertyName("color")]
    public string? Color { get; init; }

    [JsonPropertyName("glyph")]
    public string? Glyph { get; init; }
}

public static class FleetFile
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    public static IReadOnlyDictionary<string, FleetEntry> Parse(string json)
    {
        try
        {
            var decoded = JsonSerializer.Deserialize<Dictionary<string, FleetEntry>>(json, Options);
            if (decoded is null)
            {
                return new Dictionary<string, FleetEntry>();
            }

            var normalized = new Dictionary<string, FleetEntry>();
            foreach (var pair in decoded)
            {
                normalized[Hostnames.Short(pair.Key)] = pair.Value;
            }

            return normalized;
        }
        catch (JsonException)
        {
            return new Dictionary<string, FleetEntry>();
        }
    }

    public static FleetEntry? Entry(IReadOnlyDictionary<string, FleetEntry> entries, string host) =>
        entries.TryGetValue(Hostnames.Short(host), out var entry) ? entry : null;
}
