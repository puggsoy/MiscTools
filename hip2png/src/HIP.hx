package;
import sys.io.FileInput;

class HIP
{
	public function new(f:FileInput)
	{
		f.bigEndian = true;
		
		var hdr:Header = {magic: '', unk1: 0, fileLen: 0, unk2: 0, width: 0, height: 0, flags: 0, unk3: 0};
		hdr.magic = f.readString(4);
		hdr.unk1 = f.readInt32();
		hdr.fileLen = f.readInt32();
		hdr.unk2 = f.readInt32();
		hdr.width = f.readInt32();
		hdr.height = f.readInt32();
		hdr.flags = f.readInt32();
		hdr.unk3 = f.readInt32();
		
		
	}
}

private typedef Header =
{
	var magic:String;
	var unk1:Int;
	var fileLen:Int;
	var unk2:Int;
	var width:Int;
	var height:Int;
	var flags:Int;
	var unk3:Int;
}

private typedef Header2 = 
{
	var width:Int;
	var height:Int;
	var offset_x:Int;
	var offset_y:Int;
	var unk5:Int;
	var unk6:Int;
	var unk7:Int;
	var unk8:Int;
}

@:enum
private abstract HeaderType
{
	var Type1 = 0x0000;
	var Type2 = 0x2001;
}

@:enum
private abstract CompressionType
{
	var Bit8 = 0x0001;
	var Bit8RLE = 0x2001;
	var GreyscaleRLE = 0x0104;
	var Bit32RLE = 0x0110;
	var Bit32LongRLE = 0x1010;
	var LZ = 0x0210;
	var SEGS = 0x0810;
}