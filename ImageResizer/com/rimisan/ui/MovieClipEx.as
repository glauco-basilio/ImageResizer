import flash.geom.Point;
import com.rimisan.ui.style.LineStyle;
dynamic class com.rimisan.ui.MovieClipEx extends MovieClip{
		public var empClip:MovieClip;
		private var _lineStyle:LineStyle;
		public function MovieClipEx(){
			this.createEmptyMovieClip("empClip",getNextHighestDepth());
			lineStyle = new LineStyle();
		}
		public function getScaledMousePoint(amount:Number):Point{
			if(!amount) var amount = 0;
			return new Point(this._xmouse+(this._xmouse*(this._xscale+amount-100)/100),this._ymouse+(this._ymouse*(this._yscale+amount-100)/100));
		}
		public function getPointForMoveFromPoint(regX:Number,regY:Number,x:Number,y:Number):Point{
				return new Point(-regX + x, -regY + y);
		}
		public function getScaledPoint(p:Point,amount:Number){
			if(!amount) var amount = 0;
			return new Point(p.x+(p.x*(this._xscale+amount-100)/100),p.y+(p.y*(this._xscale+amount-100)/100))
		}
		public function set lineStyle(pLineStyle:LineStyle):Void{
			super.lineStyle(pLineStyle.thickness,pLineStyle.rgb,pLineStyle.alpha,pLineStyle.pixelHinting,pLineStyle.noScale,pLineStyle.capsStyle,pLineStyle.jointStyle,pLineStyle.miterLimit);
			_lineStyle = pLineStyle;
		}
		public function get lineStyle():LineStyle{
			return _lineStyle;
		}
		function drawRectangle(boxWidth:Number, boxHeight:Number,pLineStyle:LineStyle,fillColor:Number, fillAlpha:Number):Void {
				//lineStyle(pLineStyle.thickness,pLineStyle.rgb,pLineStyle.alpha,pLineStyle.pixelHinting,pLineStyle.noScale,pLineStyle.capsStyle,pLineStyle.jointStyle,pLineStyle.miterLimit);
				if(pLineStyle){
					var oldLineStyle = lineStyle;
					lineStyle = pLineStyle;
				}
				if(fillColor)
					beginFill(fillColor, (fillAlpha!=undefined) ? fillAlpha : 100 );
				moveTo(0, 0);
				lineTo(boxWidth, 0);
				lineTo(boxWidth, boxHeight);
				lineTo(0, boxHeight);
				lineTo(0, 0);
				if(fillColor)
					endFill();
				if(pLineStyle){
					lineStyle = oldLineStyle;
				}
		}




	}