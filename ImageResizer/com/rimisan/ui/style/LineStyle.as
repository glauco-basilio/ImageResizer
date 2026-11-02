class com.rimisan.ui.style.LineStyle{
		public var thickness:Number = 0;
		public var rgb:Number = 0xFFFFFF;
		private var _alpha:Number = 100;
		public var pixelHinting:Boolean;
		private var _noScale:String = "normal";
		private var _capsStyle:String = "round";
		private var _jointStyle:String = "miter";
		public var miterLimit:Number;
		public static var noScaleNormal = "normal";
		public static var noScaleNone = "none";
		public static var noScaleVertical = "vertical";
		public static var noScaleHorizontal = "horizontal";
		public static var capsStyleNone:String = "none";
		public static var capsStyleRound:String = "round";
		public static var capsStyleSquare:String = "square";
		public static var jointStyleMiter:String = "miter";
		public static var jointStyleRound:String = "round";
		public static var jointStyleBevel:String = "bevel";
		public function set alpha(b:Number):Void{
			if(b>100 || b < 0){
				var e:Error =  new Error();
				e.message = "Alpha deve ser um valor entre 0 e 100.";
				e.name = "Range Error";
				throw e;
			}
			_alpha = b;
		}
		public function get alpha():Number{
			return _alpha;
		}
		public function set noScale(s:String):Void{
			if(s==LineStyle.noScaleNormal || s==LineStyle.noScaleNone 
			   || s==LineStyle.noScaleVertical || s==LineStyle.noScaleHorizontal){
				_noScale = s;
			}
			else{
				var e:Error =  new Error();
				e.message = "noScale desconhecido";
				e.name = "noScale Error";
				throw e;
			}
		}
		public function get noScale():String{
			return _noScale;
		}
		public function set capsStyle(s:String):Void{
			if(s==LineStyle.capsStyleNone || s==LineStyle.capsStyleRound 
			   || s==LineStyle.capsStyleSquare){
				_capsStyle = s;
			}
			else{
				var e:Error =  new Error();
				e.message = "capsStyle desconhecido";
				e.name = "CapsStyle Error";
				throw e;
			}
		}
		public function get capsStyle():String{
			return _capsStyle;
		}		
		public function set jointStyle(s:String):Void{
			if(s==LineStyle.jointStyleMiter || s==LineStyle.jointStyleBevel 
			   || s==LineStyle.jointStyleRound || s==LineStyle.noScaleHorizontal){
				_jointStyle = s;
			}
			else{
				var e:Error =  new Error();
				e.message = "jointStyle desconhecido";
				e.name = "JointStyle Error";
				throw e;
			}
		}
		public function get jointStyle():String{
			return _jointStyle;
		}		
	}