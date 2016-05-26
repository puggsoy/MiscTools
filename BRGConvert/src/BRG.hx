package ;
import format.png.Data;
import format.png.Tools;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;

class BRG
{
	static public function convertFile(bytes:Bytes):Data
	{
		var input:BytesInput = new BytesInput(bytes);
		input.bigEndian = false;
		
		var magic:Int = input.readUInt24();
		
		if (magic != 0x185242)
		{
			Sys.println("Incorrect header! Corrupt/incorrect file.");
			return null;
		}
		
		input.position = 6;
		
		var width:Int = input.readInt32();
		var height:Int = input.readInt32();
		
		if ((input.length - 0x18) / 2 != (width * height))
		{
			Sys.println("This file doesn't seem to contain any graphic data!");
			return null;
		}
		
		input.position = 0x18;
		
		var rgbOut:BytesOutput = new BytesOutput();
		
		while (input.position < input.length)
		{
			var rgb:Int = input.readUInt16();
			rgbOut.writeUInt24(RGB565toRGB32(rgb));
		}
		
		var outData:Data = Tools.buildRGB(width, height, rgbOut.getBytes());
		
		return outData;
	}
	
	static private function RGB565toRGB32(rgb:Int):Int
	{
		var r:Int = (rgb & 0xF800) >> 11;
		var g:Int = (rgb & 0x7E0) >> 5;
		var b:Int = rgb & 0x1F;
		
		r <<= 3;
		g <<= 2;
		b <<= 3;
		
		return (r << 16) + (g << 8) + b;
	}
}