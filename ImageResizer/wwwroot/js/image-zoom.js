/* global createjs */
(function (global) {
  "use strict";

  class ImageZoom {
    static fitContain(imageWidth, imageHeight, boxWidth, boxHeight) {
      const scale = Math.min(boxWidth / imageWidth, boxHeight / imageHeight);
      const width = Math.min(boxWidth, Math.max(1, Math.round(imageWidth * scale)));
      const height = Math.min(boxHeight, Math.max(1, Math.round(imageHeight * scale)));
      return {
        width,
        height,
        scaleX: width / imageWidth,
        scaleY: height / imageHeight,
        x: (boxWidth - width) / 2,
        y: (boxHeight - height) / 2
      };
    }

    constructor(options) {
      if (!global.createjs) throw new Error("Load CreateJS before image-zoom.js.");
      if (!options || !options.canvas || !options.image) {
        throw new Error("ImageZoom requires a canvas and an image URL.");
      }

      this.canvas = options.canvas;
      this.viewportWidth = Number(options.width || this.canvas.width || 600);
      this.viewportHeight = Number(options.height || this.canvas.height || 400);
      this.zoomPercent = Number(options.zoomPercent ?? 50);
      this.easingDuration = Number(options.easingDuration ?? 250);
      this.imageUrl = options.image;
      this.isLoading = false;
      this.zoom = 1;
      this._drag = null;
      this._navigatorDrag = false;
      this._image = null;
      this._previewImage = null;
      this._loadToken = 0;
      this._cropToken = 0;
      this._baseScaleX = 1;
      this._baseScaleY = 1;
      this._displayWidth = 0;
      this._displayHeight = 0;
      this._onLoad = options.onLoad || function () {};
      this._onError = options.onError || function () {};
      this._onChange = options.onChange || function () {};
      this._onProgress = options.onProgress || function () {};
      this._progressRequestId = 0;

      this.canvas.width = this.viewportWidth;
      this.canvas.height = this.viewportHeight;
      this.stage = new createjs.Stage(this.canvas);
      this.stage.enableMouseOver(10);
      this.stage.mouseMoveOutside = true;
      createjs.Touch.enable(this.stage);

      this.content = new createjs.Container();
      this.bitmap = new createjs.Bitmap(null);
      this.content.addChild(this.bitmap);
      this.mask = new createjs.Shape();
      this.mask.graphics.beginFill("#000").drawRect(0, 0, this.viewportWidth, this.viewportHeight);
      this.content.mask = this.mask;
      this.stage.addChild(this.content);
      this.cropContent = new createjs.Container();
      this.cropBitmap = new createjs.Bitmap(null);
      this.cropContent.addChild(this.cropBitmap);
      this.cropMask = new createjs.Shape();
      this.cropMask.graphics.beginFill("#000").drawRect(0, 0, this.viewportWidth, this.viewportHeight);
      this.cropContent.mask = this.cropMask;
      this.cropContent.visible = false;
      this.stage.addChild(this.cropContent);

      this._onStageDown = this._handleStageDown.bind(this);
      this._onStageMove = this._handleStageMove.bind(this);
      this._onStageUp = this._handleStageUp.bind(this);
      this._onWheel = this._handleWheel.bind(this);
      this._onTick = () => this._syncNavigator();
      this.stage.on("stagemousedown", this._onStageDown);
      this.stage.on("stagemousemove", this._onStageMove);
      this.stage.on("stagemouseup", this._onStageUp);
      this.canvas.addEventListener("wheel", this._onWheel, { passive: false });
      createjs.Ticker.addEventListener("tick", this.stage);
      createjs.Ticker.addEventListener("tick", this._onTick);

      if (options.navigatorCanvas) this._createNavigator(options.navigatorCanvas);
      this.setImage(this.imageUrl);
    }

    async setImage(url) {
      this.imageUrl = url;
      this.isLoading = true;
      this.cropContent.visible = false;
      const loadToken = ++this._loadToken;
      this._cropToken += 1;
      try {
        const sourceUrl = new URL(url, document.baseURI);
        if (sourceUrl.origin !== location.origin) {
          throw new Error("ImageZoom endpoints require an image served by this application.");
        }

        this._fileName = decodeURIComponent(sourceUrl.pathname.split("/").pop());
        this._resizerUrl = new URL("Resizer.aspx", sourceUrl);
        const infoUrl = new URL("ImageInfo.aspx", sourceUrl);
        infoUrl.searchParams.set("ImageFileStr", this._fileName);
        const infoRequestId = ++this._progressRequestId;
        this._onProgress({ requestId: infoRequestId, active: true, indeterminate: true, action: "Info" });
        let infoXml;
        try {
          const infoResponse = await fetch(infoUrl);
          if (!infoResponse.ok) throw new Error(`ImageInfo.aspx returned HTTP ${infoResponse.status}.`);
          infoXml = await infoResponse.text();
        } finally {
          this._onProgress({ requestId: infoRequestId, active: false, percent: 100, action: "Info" });
        }
        const xml = new DOMParser().parseFromString(infoXml, "text/xml");
        const info = xml.querySelector("imageinfo img");
        const naturalWidth = Number(info?.getAttribute("width"));
        const naturalHeight = Number(info?.getAttribute("height"));
        if (!naturalWidth || !naturalHeight) throw new Error("ImageInfo.aspx did not return image dimensions.");
        if (loadToken !== this._loadToken) return;

        this._image = { naturalWidth, naturalHeight };
        const fit = ImageZoom.fitContain(
          naturalWidth,
          naturalHeight,
          this.viewportWidth,
          this.viewportHeight
        );
        this._displayWidth = fit.width;
        this._displayHeight = fit.height;
        this._baseScaleX = fit.scaleX;
        this._baseScaleY = fit.scaleY;

        const preview = await this._fetchImage("Resize", {
          w: this._displayWidth,
          h: this._displayHeight
        });
        if (loadToken !== this._loadToken) return;
        this._previewImage = preview;
        this.bitmap.image = preview;
        this.bitmap.setTransform(0, 0, 1, 1);
        this.zoom = 1;
        this.content.scaleX = 1;
        this.content.scaleY = 1;
        this.content.x = fit.x;
        this.content.y = fit.y;
        this.isLoading = false;
        this._updateNavigatorImage();
        this._syncNavigator();
        this._onLoad({ image: this.imageUrl, width: naturalWidth, height: naturalHeight });
        this._onChange(this.getStatus());
      } catch (error) {
        if (loadToken !== this._loadToken) return;
        this.isLoading = false;
        this._onError(error);
      }
    }

    async _fetchImage(action, parameters) {
      const url = new URL(this._resizerUrl);
      url.searchParams.set("Action", action);
      url.searchParams.set("ImageFileStr", this._fileName);
      Object.entries(parameters).forEach(([key, value]) => url.searchParams.set(key, String(value)));
      const requestId = ++this._progressRequestId;
      let objectUrl;
      try {
        this._onProgress({ requestId, active: true, percent: 0, indeterminate: true, action });
        const response = await fetch(url);
        if (!response.ok) throw new Error(`Resizer.aspx returned HTTP ${response.status}.`);
        const total = Number(response.headers.get("content-length"));
        let blob;
        if (response.body?.getReader) {
          const reader = response.body.getReader();
          const chunks = [];
          let received = 0;
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            chunks.push(value);
            received += value.byteLength;
            this._onProgress({
              requestId,
              active: true,
              percent: total > 0 ? Math.min(100, Math.round(received * 100 / total)) : 0,
              indeterminate: !(total > 0),
              action
            });
          }
          blob = new Blob(chunks, { type: response.headers.get("content-type") || "image/jpeg" });
        } else {
          blob = await response.blob();
        }
        objectUrl = URL.createObjectURL(blob);
        return await new Promise((resolve, reject) => {
          const image = new Image();
          image.onload = () => resolve(image);
          image.onerror = () => reject(new Error("The resized image response could not be decoded."));
          image.src = objectUrl;
        });
      } finally {
        if (objectUrl) URL.revokeObjectURL(objectUrl);
        this._onProgress({ requestId, active: false, percent: 100, indeterminate: false, action });
      }
    }

    resize(width, height) {
      this.viewportWidth = Math.max(1, Math.round(width));
      this.viewportHeight = Math.max(1, Math.round(height));
      this.canvas.width = this.viewportWidth;
      this.canvas.height = this.viewportHeight;
      this.mask.graphics.clear().beginFill("#000")
        .drawRect(0, 0, this.viewportWidth, this.viewportHeight);
      this.cropMask.graphics.clear().beginFill("#000")
        .drawRect(0, 0, this.viewportWidth, this.viewportHeight);
      this.setImage(this.imageUrl);
    }

    get width() { return this.viewportWidth; }
    get height() { return this.viewportHeight; }
    get Image() { return this.imageUrl; }
    set Image(url) { this.setImage(url); }
    get IsLoading() { return this.isLoading; }
    get ZoomPercent() { return this.zoomPercent; }
    set ZoomPercent(value) { this.zoomPercent = Number(value); }
    get EasingDuration() { return this.easingDuration; }
    set EasingDuration(value) { this.easingDuration = Number(value); }

    zoomOn(x, y, amount = this.zoomPercent, animate = true) {
      if (!this._image || this.isLoading) return;
      const oldScale = this.content.scaleX || this.zoom;
      const newScale = Math.max(1, oldScale + Number(amount) / 100);
      if (newScale === oldScale) return;

      const ratio = newScale / oldScale;
      const nextX = x - (x - this.content.x) * ratio;
      const nextY = y - (y - this.content.y) * ratio;
      this._applyView(newScale, nextX, nextY, animate);
    }

    zoomMore() {
      this.zoomOn(this.viewportWidth / 2, this.viewportHeight / 2, Math.abs(this.zoomPercent));
    }

    zoomLess() {
      this.zoomOn(this.viewportWidth / 2, this.viewportHeight / 2, -Math.abs(this.zoomPercent));
    }

    zoomReset(animate = true) {
      if (!this._image) return;
      this._applyView(1,
        (this.viewportWidth - this._displayWidth) / 2,
        (this.viewportHeight - this._displayHeight) / 2,
        animate);
    }

    centerOn(x, y, animate = false) {
      if (!this._image) return;
      this._applyView(this.zoom,
        this.viewportWidth / 2 - x * this._baseScaleX * this.zoom,
        this.viewportHeight / 2 - y * this._baseScaleY * this.zoom,
        animate);
    }

    toggleZoomMode() {
      this.zoomPercent *= -1;
    }

    ZoomMore() { this.zoomMore(); }
    ZoomLess() { this.zoomLess(); }
    ZoomReset() { this.zoomReset(); }
    ZoomOn(x, y, percent, tween) { this.zoomOn(x, y, percent, tween); }
    CenterOn(x, y, cropOnEnd, useTween) { this.centerOn(x, y, Boolean(useTween)); }

    getStatus() {
      return {
        image: this.imageUrl,
        zoomPercent: Math.round(this.zoom * 100),
        width: this._image ? this._image.naturalWidth : 0,
        height: this._image ? this._image.naturalHeight : 0,
        isLoading: this.isLoading
      };
    }

    destroy() {
      createjs.Ticker.removeEventListener("tick", this.stage);
      createjs.Ticker.removeEventListener("tick", this._onTick);
      this.stage.off("stagemousedown", this._onStageDown);
      this.stage.off("stagemousemove", this._onStageMove);
      this.stage.off("stagemouseup", this._onStageUp);
      this.canvas.removeEventListener("wheel", this._onWheel);
      createjs.Touch.disable(this.stage);
      if (this.navigatorStage) {
        createjs.Ticker.removeEventListener("tick", this.navigatorStage);
        this.navigatorStage.off("stagemousedown", this._onNavigatorDown);
        this.navigatorStage.off("stagemousemove", this._onNavigatorMove);
        this.navigatorStage.off("stagemouseup", this._onNavigatorUp);
        createjs.Touch.disable(this.navigatorStage);
      }
    }

    _applyView(scale, x, y, animate) {
      const position = this._clampPosition(x, y, scale);
      this.zoom = scale;
      this.cropContent.visible = false;
      this._cropToken += 1;
      createjs.Tween.removeTweens(this.content);
      const duration = animate ? Math.max(0, this.easingDuration) : 0;
      createjs.Tween.get(this.content)
        .to({ x: position.x, y: position.y, scaleX: scale, scaleY: scale }, duration)
        .call(() => {
          this._syncNavigator();
          this._requestCrop();
          this._onChange(this.getStatus());
        });
      this._syncNavigator();
    }

    _clampPosition(x, y, scale) {
      const width = this._displayWidth * scale;
      const height = this._displayHeight * scale;
      return {
        x: width <= this.viewportWidth
          ? (this.viewportWidth - width) / 2
          : Math.min(0, Math.max(this.viewportWidth - width, x)),
        y: height <= this.viewportHeight
          ? (this.viewportHeight - height) / 2
          : Math.min(0, Math.max(this.viewportHeight - height, y))
      };
    }

    async _requestCrop() {
      if (!this._image || this.isLoading || !this._resizerUrl) return;
      const cropToken = ++this._cropToken;
      this.cropContent.visible = false;
      try {
        const crop = await this._fetchImage("Crop", {
          w: Math.max(1, Math.round(this._displayWidth * this.zoom)),
          h: Math.max(1, Math.round(this._displayHeight * this.zoom)),
          wP: this.viewportWidth,
          hP: this.viewportHeight,
          x: Math.round(-this.content.x),
          y: Math.round(-this.content.y)
        });
        if (cropToken !== this._cropToken) return;
        this.cropBitmap.image = crop;
        this.cropBitmap.setTransform(0, 0, 1, 1);
        this.cropContent.x = 0;
        this.cropContent.y = 0;
        this.cropContent.scaleX = this.cropContent.scaleY = 1;
        this.cropContent.visible = true;
      } catch (error) {
        if (cropToken === this._cropToken) this._onError(error);
      }
    }

    _handleStageDown(event) {
      if (!this._image || this.isLoading) return;
      this._drag = {
        startX: event.stageX,
        startY: event.stageY,
        imageX: this.content.x,
        imageY: this.content.y,
        moved: false
      };
    }

    _handleStageMove(event) {
      if (!this._drag) return;
      const dx = event.stageX - this._drag.startX;
      const dy = event.stageY - this._drag.startY;
      if (Math.abs(dx) + Math.abs(dy) > 3) this._drag.moved = true;
      if (!this._drag.moved) return;
      this.cropContent.visible = false;
      this._cropToken += 1;
      const position = this._clampPosition(
        this._drag.imageX + dx,
        this._drag.imageY + dy,
        this.zoom
      );
      this.content.x = position.x;
      this.content.y = position.y;
      this._syncNavigator();
    }

    _handleStageUp(event) {
      if (!this._drag) return;
      const drag = this._drag;
      this._drag = null;
      if (drag.moved) {
        this._requestCrop();
        this._onChange(this.getStatus());
        return;
      }
      this.zoomOn(event.stageX, event.stageY, this.zoomPercent);
    }

    _handleWheel(event) {
      if (!this._image) return;
      event.preventDefault();
      const bounds = this.canvas.getBoundingClientRect();
      const x = (event.clientX - bounds.left) * this.viewportWidth / bounds.width;
      const y = (event.clientY - bounds.top) * this.viewportHeight / bounds.height;
      this.zoomOn(x, y, event.deltaY < 0 ? Math.abs(this.zoomPercent) : -Math.abs(this.zoomPercent));
    }

    _createNavigator(canvas) {
      this.navigatorCanvas = canvas;
      this.navigatorWidth = Number(canvas.width || 180);
      this.navigatorHeight = Number(canvas.height || 120);
      canvas.width = this.navigatorWidth;
      canvas.height = this.navigatorHeight;
      this.navigatorStage = new createjs.Stage(canvas);
      this.navigatorStage.mouseMoveOutside = true;
      createjs.Touch.enable(this.navigatorStage);
      createjs.Ticker.addEventListener("tick", this.navigatorStage);
      this.navigatorBitmap = new createjs.Bitmap(null);
      this.navigatorGuide = new createjs.Shape();
      this.navigatorStage.addChild(this.navigatorBitmap, this.navigatorGuide);
      this._onNavigatorDown = this._handleNavigatorDown.bind(this);
      this._onNavigatorMove = this._handleNavigatorMove.bind(this);
      this._onNavigatorUp = () => {
        this._navigatorDrag = false;
        this._requestCrop();
      };
      this.navigatorStage.on("stagemousedown", this._onNavigatorDown);
      this.navigatorStage.on("stagemousemove", this._onNavigatorMove);
      this.navigatorStage.on("stagemouseup", this._onNavigatorUp);
    }

    _updateNavigatorImage() {
      if (!this.navigatorStage || !this._previewImage || !this._image) return;
      const scale = Math.min(
        this.navigatorWidth / this._previewImage.naturalWidth,
        this.navigatorHeight / this._previewImage.naturalHeight
      );
      this.navigatorBitmap.image = this._previewImage;
      this.navigatorBitmap.setTransform(
        (this.navigatorWidth - this._previewImage.naturalWidth * scale) / 2,
        (this.navigatorHeight - this._previewImage.naturalHeight * scale) / 2,
        scale,
        scale
      );
      this._navigatorScaleX = scale * this._displayWidth / this._image.naturalWidth;
      this._navigatorScaleY = scale * this._displayHeight / this._image.naturalHeight;
      this._navigatorOffsetX = (this.navigatorWidth - this._previewImage.naturalWidth * scale) / 2;
      this._navigatorOffsetY = (this.navigatorHeight - this._previewImage.naturalHeight * scale) / 2;
    }

    _syncNavigator() {
      if (!this.navigatorStage || !this._image) return;
      const zoom = this.content.scaleX || this.zoom;
      const scaleX = this._baseScaleX * zoom;
      const scaleY = this._baseScaleY * zoom;
      const left = Math.max(0, (0 - this.content.x) / scaleX);
      const top = Math.max(0, (0 - this.content.y) / scaleY);
      const width = Math.min(this._image.naturalWidth,
        this.viewportWidth / scaleX);
      const height = Math.min(this._image.naturalHeight,
        this.viewportHeight / scaleY);
      this.navigatorGuide.graphics.clear()
        .beginFill("rgba(255,255,255,0.28)")
        .beginStroke("#ff3030")
        .setStrokeStyle(2)
        .drawRect(this._navigatorOffsetX + left * this._navigatorScaleX,
          this._navigatorOffsetY + top * this._navigatorScaleY,
          Math.max(1, width * this._navigatorScaleX),
          Math.max(1, height * this._navigatorScaleY));
      this._navigatorRect = {
        x: this._navigatorOffsetX + left * this._navigatorScaleX,
        y: this._navigatorOffsetY + top * this._navigatorScaleY,
        width: Math.max(1, width * this._navigatorScaleX),
        height: Math.max(1, height * this._navigatorScaleY)
      };
    }

    _handleNavigatorDown(event) {
      if (!this._image) return;
      this.cropContent.visible = false;
      this._cropToken += 1;
      const rect = this._navigatorRect;
      const draggingFrame = rect && event.stageX >= rect.x && event.stageX <= rect.x + rect.width
        && event.stageY >= rect.y && event.stageY <= rect.y + rect.height;
      this._navigatorDrag = draggingFrame
        ? { mode: "frame", offsetX: event.stageX - rect.x, offsetY: event.stageY - rect.y }
        : { mode: "center" };
      if (!draggingFrame) this._centerOnNavigatorPoint(event.stageX, event.stageY);
    }

    _handleNavigatorMove(event) {
      if (!this._navigatorDrag) return;
      if (this._navigatorDrag.mode === "center") {
        this._centerOnNavigatorPoint(event.stageX, event.stageY);
        return;
      }

      const imageX = (event.stageX - this._navigatorDrag.offsetX - this._navigatorOffsetX) / this._navigatorScaleX;
      const imageY = (event.stageY - this._navigatorDrag.offsetY - this._navigatorOffsetY) / this._navigatorScaleY;
      const position = this._clampPosition(
        -imageX * this._baseScaleX * this.zoom,
        -imageY * this._baseScaleY * this.zoom,
        this.zoom
      );
      this.content.x = position.x;
      this.content.y = position.y;
      this._syncNavigator();
    }

    _centerOnNavigatorPoint(x, y) {
      const offsetX = this._navigatorOffsetX;
      const offsetY = this._navigatorOffsetY;
      const imageX = Math.max(0, Math.min(this._image.naturalWidth,
        (x - offsetX) / this._navigatorScaleX));
      const imageY = Math.max(0, Math.min(this._image.naturalHeight,
        (y - offsetY) / this._navigatorScaleY));
      this.centerOn(imageX, imageY, false);
    }
  }

  global.ImageZoom = ImageZoom;
})(window);
