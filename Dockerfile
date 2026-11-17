FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY ImageResizer/ImageResizer.csproj ImageResizer/
RUN dotnet restore ImageResizer/ImageResizer.csproj
COPY ImageResizer/ ImageResizer/
RUN dotnet publish ImageResizer/ImageResizer.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "ImageResizer.dll"]
