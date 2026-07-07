using System.Globalization;
using System.Text;

namespace Nameplate.Core;

public sealed record MachineIdentity(string Name, string ColorHex, string Glyph = "")
{
    public MachineIdentity Normalize() => this with
    {
        ColorHex = global::Nameplate.Core.ColorHex.Normalize(ColorHex) ?? NameplatePalette.Fallback.Hex,
        Glyph = Glyph ?? string.Empty,
    };
}

public sealed record PaletteColor(string Name, string Hex);

public static class NameplatePalette
{
    public static IReadOnlyList<PaletteColor> Colors { get; } =
    [
        new("Lobster", "#E24B30"),
        new("Amber", "#EF9F27"),
        new("Lime", "#8BC34A"),
        new("Jade", "#1D9E75"),
        new("Cyan", "#22B8CF"),
        new("Azure", "#378ADD"),
        new("Violet", "#7F77DD"),
        new("Magenta", "#D4537E"),
    ];

    public static PaletteColor Fallback => Colors[3];

    public static PaletteColor DefaultColor(string host)
    {
        var normalized = Hostnames.Short(host);
        const ulong offset = 0xcbf29ce484222325;
        const ulong prime = 0x100000001b3;
        var hash = offset;
        foreach (var value in Encoding.UTF8.GetBytes(normalized))
        {
            hash ^= value;
            hash = unchecked(hash * prime);
        }

        return Colors[(int)(hash % (ulong)Colors.Count)];
    }
}

public static class ColorHex
{
    public static string? Normalize(string? raw)
    {
        if (raw is null)
        {
            return null;
        }

        var text = raw.Trim().ToUpperInvariant();
        if (text.StartsWith('#'))
        {
            text = text[1..];
        }
        if (text.Length == 3)
        {
            text = string.Concat(text.Select(character => $"{character}{character}"));
        }

        if (text.Length != 6 || !text.All(Uri.IsHexDigit))
        {
            return null;
        }

        return $"#{text}";
    }

    public static double RelativeLuminance(string hex)
    {
        var normalized = Normalize(hex);
        if (normalized is null)
        {
            return 0;
        }

        var red = byte.Parse(normalized.AsSpan(1, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture) / 255d;
        var green = byte.Parse(normalized.AsSpan(3, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture) / 255d;
        var blue = byte.Parse(normalized.AsSpan(5, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture) / 255d;
        return 0.2126 * Linearize(red) + 0.7152 * Linearize(green) + 0.0722 * Linearize(blue);
    }

    public static bool PrefersDarkText(string hex) => RelativeLuminance(hex) > 0.4;

    private static double Linearize(double component) =>
        component <= 0.03928 ? component / 12.92 : Math.Pow((component + 0.055) / 1.055, 2.4);
}

public static class Hostnames
{
    public static string Short(string host)
    {
        var lowered = host.Trim().ToLowerInvariant();
        var first = lowered.Split('.', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault();
        return first ?? lowered;
    }
}

public enum ScreenCorner
{
    TopLeft,
    TopRight,
    BottomLeft,
    BottomRight,
}
