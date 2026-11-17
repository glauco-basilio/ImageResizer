# ImageZoom — case de produto e reconstrução

O ImageZoom começou como uma extensão para Adobe Flash, vendida junto com um backend sob encomenda. Este repositório preserva os artefatos históricos do produto e apresenta uma reconstrução executável da experiência no navegador atual.

O objetivo é documentar um trabalho de produto e engenharia de outra época: ampliar e navegar imagens dentro de uma área limitada, oferecer uma miniatura navegável e delegar operações de imagem a um serviço. A demo atual é um case de portfólio, não uma oferta de produto nem uma tentativa de competir com serviços modernos de imagens em tiles.

## O que a demo mostra

- Visualização em canvas com zoom, arraste, enquadramento inicial e miniatura navegável.
- Backend ASP.NET Core que informa dimensões e redimensiona ou recorta imagens.
- Cache em memória para imagens processadas, limitado a 64 MB por processo, com expiração de 24 horas.
- Cache HTTP com ETag para permitir reutilização pelo navegador e por caches intermediários.
- Página inicial que apresenta exemplos com imagens de demonstração.

A implementação atual usa CreateJS no navegador e SkiaSharp no backend. O código ActionScript original está preservado em `ImageResizer/com/rimisan/ui/`; os arquivos `.fla`, `.swf` e `.swc` guardam materiais históricos do projeto Flash. A demo executável moderna está em `ImageResizer/wwwroot`.

## Executar localmente

Requer o .NET 10 SDK.

**Demo ao vivo:** [ImageZoom no Hostinger](https://app.semneurose.com.br/imagezoom/)

```sh
dotnet build ImageResizer.sln
dotnet run --project ImageResizer/ImageResizer.csproj
```

Abra o endereço impresso pelo `dotnet run` (por padrão, `http://localhost:5080/`). A página inicial lista as imagens e abre cada uma no visualizador. O CreateJS 1.0.0 é carregado de um CDN, então a demo precisa de internet no navegador.

O deploy usa o `Dockerfile` deste repositório e publica a aplicação sob o prefixo `/imagezoom`.

## API legada preservada

As rotas compatíveis com o contrato antigo continuam disponíveis:

- `/Images/ImageInfo.aspx` e `/Exemplos/images/ImageInfo.aspx`
- `/Images/Resizer.aspx` e `/Exemplos/images/Resizer.aspx`

Os caminhos de imagem são resolvidos dentro de `ImageResizer/wwwroot`.

## Escopo e limites

Esta reconstrução serve para explorar e apresentar o projeto original. O processamento atual decodifica a imagem no backend antes de redimensionar ou recortar; imagens de centenas de megapixels exigiriam outra arquitetura e limites explícitos de memória. Para esse cenário, tiles multirresolução e carregamento sob demanda seriam uma evolução separada, não uma capacidade desta demo.

A demonstração mantém dependências e escolhas técnicas compatíveis com o escopo do case. Não há implementações planejadas de Angular, React, Vue ou outros backends neste repositório.
