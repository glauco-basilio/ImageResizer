using System.Globalization;
using Microsoft.Extensions.Caching.Memory;
using System.Security.Cryptography;
using System.Xml;
using SkiaSharp;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddMemoryCache(options => options.SizeLimit = 64 * 1024 * 1024);
var app = builder.Build();
var imageCache = app.Services.GetRequiredService<IMemoryCache>();
var contentRoot = Path.GetFullPath(app.Environment.WebRootPath ?? Path.Combine(app.Environment.ContentRootPath, "wwwroot"));

var pathBase = builder.Configuration["AppBasePath"];
if (!string.IsNullOrWhiteSpace(pathBase))
{
    app.Use(async (context, next) =>
    {
        if (context.Request.Path == pathBase)
        {
            context.Response.Redirect($"{pathBase}/{context.Request.QueryString}", permanent: true);
            return;
        }

        await next();
    });
    app.UsePathBase(pathBase);
}

app.UseStaticFiles();

// Serve the examples home page at the application root.
app.MapGet("/", (IWebHostEnvironment environment) => Results.File(
    Path.Combine(environment.WebRootPath ?? Path.Combine(environment.ContentRootPath, "wwwroot"), "index.html"),
    "text/html; charset=utf-8"));

app.MapGet("/Images/Resizer.aspx", (HttpContext context) => ResizeImage(context, contentRoot, imageCache));
app.MapGet("/Exemplos/images/Resizer.aspx", (HttpContext context) => ResizeImage(context, contentRoot, imageCache));
app.MapGet("/Images/ImageInfo.aspx", (HttpContext context) => ImageInfo(context, contentRoot));
app.MapGet("/Exemplos/images/ImageInfo.aspx", (HttpContext context) => ImageInfo(context, contentRoot));

app.Run();

static IResult ResizeImage(HttpContext context, string contentRoot, IMemoryCache imageCache)
{
    var relativeFile = context.Request.Query["ImageFileStr"].ToString();
    if (!TryResolveImage(contentRoot, context.Request.Path, relativeFile, out var filePath))
        return Results.BadRequest("ImageFileStr must identify an image inside the application.");

    if (!File.Exists(filePath))
        return Results.NotFound();

    var sourceInfo = new FileInfo(filePath);
    var cacheKey = string.Join('|',
        Path.GetRelativePath(contentRoot, filePath),
        sourceInfo.Length.ToString(CultureInfo.InvariantCulture),
        sourceInfo.LastWriteTimeUtc.Ticks.ToString(CultureInfo.InvariantCulture),
        context.Request.QueryString.Value ?? string.Empty);
    var cacheKeyHash = Convert.ToHexString(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(cacheKey)));
    var etag = $"\"{cacheKeyHash}\"";
    context.Response.Headers.ETag = etag;
    context.Response.Headers.CacheControl = "public, max-age=31536000, immutable";
    context.Response.Headers.LastModified = sourceInfo.LastWriteTimeUtc.ToString("R", CultureInfo.InvariantCulture);

    if (context.Request.Headers.IfNoneMatch.Any(value => value == "*" || value == etag))
        return Results.StatusCode(StatusCodes.Status304NotModified);

    if (imageCache.TryGetValue<byte[]>(cacheKeyHash, out var cachedImage))
        return Results.Bytes(cachedImage!, "image/jpeg");

    try
    {
        var image = SKBitmap.Decode(filePath);
        if (image is null)
            return Results.BadRequest("The selected file is not a supported image.");

        var processedImage = image;
        try
        {
            var action = context.Request.Query["Action"].ToString();
            switch (action)
            {
                case "Resize":
                    processedImage = Resize(image, PositiveInt(context, "w"), PositiveInt(context, "h"));
                    break;
                case "Scale":
                    var percent = PositiveInt(context, "percent");
                    processedImage = Resize(image,
                        Math.Max(1, image.Width * percent / 100),
                        Math.Max(1, image.Height * percent / 100));
                    break;
                case "Crop":
                    var width = PositiveInt(context, "w");
                    var height = PositiveInt(context, "h");
                    var cropWidth = PositiveInt(context, "wP");
                    var cropHeight = PositiveInt(context, "hP");
                    var x = Integer(context, "x");
                    var y = Integer(context, "y");
                    using (var resized = Resize(image, width, height))
                        processedImage = Crop(resized, x, y, cropWidth, cropHeight);
                    break;
                case "":
                    break;
                default:
                    return Results.BadRequest("Action must be Resize, Scale, or Crop.");
            }

            using var output = new MemoryStream();
            using var encoded = SKImage.FromBitmap(processedImage);
            using var data = encoded.Encode(SKEncodedImageFormat.Jpeg, 90);
            data.SaveTo(output);
            var imageBytes = output.ToArray();
            imageCache.Set(cacheKeyHash, imageBytes, new MemoryCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(24),
                Size = imageBytes.Length
            });
            return Results.Bytes(imageBytes, "image/jpeg");
        }
        finally
        {
            if (!ReferenceEquals(image, processedImage))
                processedImage.Dispose();
            image.Dispose();
        }
    }
    catch (ArgumentException)
    {
        return Results.BadRequest("The image dimensions or crop coordinates are invalid.");
    }
    catch (FormatException)
    {
        return Results.BadRequest("Image dimensions must be positive integers.");
    }
}

static IResult ImageInfo(HttpContext context, string contentRoot)
{
    var relativeFile = context.Request.Query["ImageFileStr"].ToString();
    var xml = new XmlDocument();
    var root = xml.CreateElement("imageinfo");
    xml.AppendChild(root);

    if (TryResolveImage(contentRoot, context.Request.Path, relativeFile, out var filePath) && File.Exists(filePath))
    {
        using var image = SKBitmap.Decode(filePath);
        if (image is not null)
        {
            var info = xml.CreateElement("img");
            info.SetAttribute("width", image.Width.ToString(CultureInfo.InvariantCulture));
            info.SetAttribute("height", image.Height.ToString(CultureInfo.InvariantCulture));
            root.AppendChild(info);
        }
    }

    return Results.Text(xml.OuterXml, "text/xml", System.Text.Encoding.UTF8);
}

static SKBitmap Resize(SKBitmap source, int width, int height)
{
    var result = new SKBitmap(width, height, source.ColorType, source.AlphaType);
    using var canvas = new SKCanvas(result);
    canvas.Clear(SKColors.Black);
    using var sourceImage = SKImage.FromBitmap(source);
    canvas.DrawImage(sourceImage,
        new SKRect(0, 0, source.Width, source.Height),
        new SKRect(0, 0, width, height),
        new SKSamplingOptions(SKFilterMode.Linear));
    return result;
}

static SKBitmap Crop(SKBitmap source, int x, int y, int width, int height)
{
    var result = new SKBitmap(width, height, source.ColorType, source.AlphaType);
    using var canvas = new SKCanvas(result);
    canvas.Clear(SKColors.Black);

    var sourceLeft = Math.Max(0, x);
    var sourceTop = Math.Max(0, y);
    var sourceRight = Math.Min(source.Width, x + width);
    var sourceBottom = Math.Min(source.Height, y + height);
    if (sourceRight > sourceLeft && sourceBottom > sourceTop)
    {
        var sourceRect = new SKRect(sourceLeft, sourceTop, sourceRight, sourceBottom);
        var destinationRect = new SKRect(
            sourceLeft - x,
            sourceTop - y,
            sourceRight - x,
            sourceBottom - y);
        canvas.DrawBitmap(source, sourceRect, destinationRect);
    }
    return result;
}

static bool TryResolveImage(string contentRoot, PathString requestPath, string relativeFile, out string filePath)
{
    filePath = string.Empty;
    if (string.IsNullOrWhiteSpace(relativeFile) || Path.IsPathRooted(relativeFile))
        return false;

    var endpointDirectory = Path.GetDirectoryName(requestPath.Value ?? string.Empty)?.TrimStart('/', '\\') ?? string.Empty;
    var candidate = Path.GetFullPath(Path.Combine(contentRoot, endpointDirectory, relativeFile));
    var rootWithSeparator = contentRoot.EndsWith(Path.DirectorySeparatorChar)
        ? contentRoot
        : contentRoot + Path.DirectorySeparatorChar;
    if (!candidate.StartsWith(rootWithSeparator, OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal))
        return false;

    filePath = candidate;
    return true;
}

static int PositiveInt(HttpContext context, string name)
{
    if (!int.TryParse(context.Request.Query[name], NumberStyles.Integer, CultureInfo.InvariantCulture, out var value) || value <= 0)
        throw new FormatException();
    return value;
}

static int Integer(HttpContext context, string name)
{
    if (!int.TryParse(context.Request.Query[name], NumberStyles.Integer, CultureInfo.InvariantCulture, out var value))
        throw new FormatException();
    return value;
}
