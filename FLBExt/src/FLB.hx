package ;
import console.End;
import format.png.Data;
import format.png.Tools;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;

class FLB
{
	private var _flbBytes:BytesInput;
	private var _goodFile:Bool = true;
	private var _beginOffset:Int;
	
	public function new(bytes:Bytes)
	{
		_flbBytes = new BytesInput(bytes);
		_flbBytes.bigEndian = false;
		
		var magic:String = _flbBytes.readString(8);
		
		if (magic != "FLBD0101")
		{
			Sys.println("Incorrect header! Corrupt/incorrect file.");
			_goodFile = false;
			return;
		}
		
		_flbBytes.position = 0x2C;
		_beginOffset = _flbBytes.position - 4 + _flbBytes.readByte();
	}
	
	public function getImages():Array<Data>
	{
		if (!_goodFile)
		{
			return null;
		}
		
		var retArray:Array<Data> = new Array<Data>();
		
		_flbBytes.position = _beginOffset;
		var header:String = _flbBytes.readString(4);
		
		while(header != "SHCH")
		{
			_flbBytes.position += 0x14;
			var width:Int = _flbBytes.readUInt16();
			var height:Int = _flbBytes.readUInt16();
			
			var pixelBytes:Bytes = Bytes.alloc(width * height * 4);
			_flbBytes.readBytes(pixelBytes, 0, width * height * 4);
			retArray.push(Tools.build32ARGB(width, height, pixelBytes));
			
			header = _flbBytes.readString(4);
		}
		
		return retArray;
	}
}