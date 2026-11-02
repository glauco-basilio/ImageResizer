# ImageZoom

ImageZoom is a cross-stack image viewer project. The goal is to keep one clearly defined image zoom experience while building idiomatic implementations for current frontend frameworks and backend languages.

## Project direction

The repository will grow in two directions:

- **Frontend components:** Web Components, Angular, React, and Vue.
- **Image-processing backends:** Node.js, PHP, Ruby, Java, and Python.

The implementations should share a documented API contract and produce the same observable behavior. Framework adapters should feel natural in their own ecosystems rather than wrapping one framework-specific component.

## Current reference implementation

The project currently contains an ASP.NET Core 10 image-processing service and a CreateJS browser viewer. The viewer supports zoom, panning, and a navigator thumbnail; the service provides image information, resize, and crop operations. The legacy ActionScript source is retained under `ImageResizer/com/rimisan/ui/` as the behavioral reference for the original Flash component.

The current implementation is the starting point for defining the shared contract. The other frontend and backend implementations are planned and have not been added yet.

## Shared behavior to preserve

- Fit the initial image inside the viewport without changing its aspect ratio.
- Zoom around the selected point and constrain panning to the image bounds.
- Show a thumbnail with a draggable viewport rectangle.
- Provide reset, zoom-in, and zoom-out controls.
- Return image dimensions and resized or cropped image data from the backend.
- Keep the browser viewer independent from backend language and framework choices.

## Run the current reference

Requires the .NET 10 SDK. From the repository root:

```sh
dotnet build ImageResizer.sln
dotnet run --project ImageResizer/ImageResizer.csproj
```

Open `/Exemplos/ImageZoom.html` at the local address printed by `dotnet run`. The demo loads CreateJS 1.0.0 from its CDN, so the browser needs internet access.

The old Flash-compatible routes are also available:

- `/Images/ImageInfo.aspx` and `/Exemplos/images/ImageInfo.aspx`
- `/Images/Resizer.aspx` and `/Exemplos/images/Resizer.aspx`

Image paths are resolved relative to the endpoint directory and must remain inside `ImageResizer/wwwroot`.

## Build status

| Area | Current status |
| --- | --- |
| ASP.NET Core 10 backend | Reference implementation |
| CreateJS viewer | Reference demo |
| Web Component | Planned |
| Angular component | Planned |
| React component | Planned |
| Vue component | Planned |
| Node.js backend | Planned |
| PHP backend | Planned |
| Ruby backend | Planned |
| Java backend | Planned |
| Python backend | Planned |
