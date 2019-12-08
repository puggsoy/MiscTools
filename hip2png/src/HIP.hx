package;
import haxe.ds.Vector;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import sys.io.FileInput;
import sys.io.FileSeek;

class HIP
{
	// Header
	private var magic:String = null;
	private var unk1:Int = -1;
	private var fileLen:Int = -1;
	private var unk2:Int = -1;
	private var width:Int = -1;
	private var height:Int = -1;
	private var flags:Int = -1;
	private var header2Len:Int = -1;
	
	// Header2
	private var width2:Int = -1;
	private var height2:Int = -1;
	private var offset_x:Int = -1;
	private var offset_y:Int = -1;
	private var unk5:Int = -1;
	private var unk6:Int = -1;
	private var unk7:Int = -1;
	private var unk8:Int = -1;
	
	// Data
	private var data:Bytes = null;
	
	// Internal palette
	public var internalPal(default, null):Vector<Int>;
	
	public function new(f:FileInput)
	{
		f.bigEndian = false;
		f.seek(0, FileSeek.SeekEnd);
		var realFileSize:Int = f.tell();
		f.seek(0, FileSeek.SeekBegin);
		
		magic = f.readString(4);
		
		if (magic != "HIP" + String.fromCharCode(0))
		{
			throw "Invalid HIP magic!";
		}
		
		unk1 = f.readInt32();
		fileLen = f.readInt32();
		
		if (fileLen != realFileSize)
		{
			// If the filesize is wrong, we may have the wrong endian
			f.bigEndian = true;
			f.seek( -8, FileSeek.SeekCur);
			
			unk1 = f.readInt32();
			fileLen = f.readInt32();
			
			if (fileLen != realFileSize)
			{
				throw "Invalid file size!";
			}
		}
		
		// Checks are over
		unk2 = f.readInt32();
		width = f.readInt32();
		height = f.readInt32();
		flags = f.readInt32();
		header2Len = f.readInt32();
		
		if (header2Len > 0)
		{
			width2 = f.readInt32();
			height2 = f.readInt32();
			offset_x = f.readInt32();
			offset_y = f.readInt32();
			unk5 = f.readInt32();
			unk6 = f.readInt32();
			unk7 = f.readInt32();
			unk8 = f.readInt32();
		}
		
		internalPal = getInternalPalette(f);
		
		//f.seek(0x400, FileSeek.SeekCur); // Skip the internal palette
		
		var bpp:Int = 1;
		var bpc:Int = 4;
		
		var compLen:Int = fileLen - f.tell();
		var decompLen:Int = width * height * bpp;
		
		data = Bytes.alloc(decompLen);
		var pos:Int = 0;
		
		// We assume this is 8bit RLE for now
		for (i in 0...Std.int(compLen / 2)) // divided by 2 since each instruction is made of 2 bytes
		{
			var pixel:Int = f.readByte();
			var repeat:Int = f.readByte();
			
			for (j in 0...repeat)
			{
				data.set(pos++, pixel);
			}
		}
	}
	
	private function getInternalPalette(f:FileInput):Vector<Int>
	{
		var palette:Vector<Int> = new Vector<Int>(0x100);
		
		for (i in 0...palette.length)
		{
			var argb:Int = f.readInt32();
			palette[i] = argb;
		}
		
		return palette;
	}
	
	public function getOutput(pal:Vector<Int>):BytesOutput
	{
		var out:BytesOutput = new BytesOutput();
		out.bigEndian = true;
		
		var pos:Int = 0;
		while (pos < data.length)
		{
			try
			{
				out.writeInt32(pal[data.get(pos)]);
			}
			catch (e:String)
			{
				trace(e);
				trace(StringTools.hex(pos));
			}
			
			pos++;
		}
		
		return out;
	}
	
	public function getWidth():Int
	{
		if (width2 != -1)
		{
			return width2;
		}
		
		return width;
	}
	
	public function getHeight():Int
	{
		if (height2 != -1)
		{
			return height2;
		}
		
		return height;
	}
}

@:enum
private abstract HeaderType(Int)
{
	var Type1 = 0x0000;
	var Type2 = 0x2001;
}

@:enum
private abstract CompressionType(Int)
{
	var Bit8 = 0x0001;
	var Bit8RLE = 0x2001;
	var GreyscaleRLE = 0x0104;
	var Bit32RLE = 0x0110;
	var Bit32LongRLE = 0x1010;
	var LZ = 0x0210;
	var SEGS = 0x0810;
}