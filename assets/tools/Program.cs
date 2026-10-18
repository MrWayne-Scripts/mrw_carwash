// Small cross-platform asset compiler and validator using the unmodified CodeWalker.Core.
using System;
using System.IO;
using System.Linq;
using System.Xml;
using CodeWalker.GameFiles;

internal static class Program
{
    private static void Require(bool ok, string message)
    {
        if (!ok) throw new InvalidDataException(message);
    }

    private static void VerifyDrawable(byte[] data, string path)
    {
        var asset = new YdrFile();
        asset.Load(data);
        var drawable = asset.Drawable;
        Require(drawable != null, "Missing drawable");
        Require(drawable.DrawableModels?.High?.Length > 0, "Missing high LOD");
        Require(drawable.DrawableModels?.Low?.Length > 0, "Missing low LOD");
        var textures = drawable.ShaderGroup?.TextureDictionary?.Textures?.data_items;
        Require(textures?.Length > 0, "Missing embedded textures");
        foreach (var texture in textures)
        {
            Require(texture.Width == 8 && texture.Height == 8 && texture.Levels == 4,
                "Unexpected texture size or mip count");
            Require(texture.Data?.FullData?.Length >= 40, "Missing DDS base/mip pixel data");
        }
        foreach (var model in drawable.DrawableModels.High.Concat(drawable.DrawableModels.Low))
        {
            Require(model.Geometries?.Length > 0, "Missing model geometry");
            foreach (var geometry in model.Geometries)
                Require(geometry.VertexBuffer != null && geometry.IndexBuffer != null, "Missing mesh buffers");
        }
        if (Path.GetFileName(path).StartsWith("mrw_pressure_stand"))
            Require(drawable.Bound != null, "Missing station collision");
        Console.WriteLine($"OK {Path.GetFileName(path)}: {data.Length} bytes, high/low LOD, {textures.Length} embedded mipmapped textures");
    }

    private static void VerifyArchetypes(byte[] data, string path)
    {
        var asset = new YtypFile();
        asset.Load(data);
        Require(asset.AllArchetypes?.Length == 2, "Expected two prop archetypes");
        Console.WriteLine($"OK {Path.GetFileName(path)}: two archetypes, {data.Length} bytes");
    }

    private static void Main(string[] args)
    {
        Require(args.Length > 0, "Supply .ydr.xml/.ytyp.xml to compile or .ydr/.ytyp to validate");
        foreach (var path in args)
        {
            string output = path;
            byte[] data;
            if (path.EndsWith(".ydr.xml"))
            {
                var asset = XmlYdr.GetYdr(File.ReadAllText(path), Path.GetDirectoryName(Path.GetFullPath(path)));
                data = asset.Save();
                output = path[..^4];
                VerifyDrawable(data, output);
                File.WriteAllBytes(output, data);
            }
            else if (path.EndsWith(".ytyp.xml"))
            {
                var doc = new XmlDocument();
                doc.Load(path);
                data = XmlMeta.GetRSCData(doc);
                Require(data != null, "Failed to serialize archetypes");
                output = path[..^4];
                VerifyArchetypes(data, output);
                File.WriteAllBytes(output, data);
            }
            else if (path.EndsWith(".ydr")) VerifyDrawable(File.ReadAllBytes(path), path);
            else if (path.EndsWith(".ytyp")) VerifyArchetypes(File.ReadAllBytes(path), path);
            else throw new InvalidDataException("Unsupported asset extension: " + path);
        }
    }
}
