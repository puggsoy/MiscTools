package;
import haxe.ds.Vector;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import sys.io.FileInput;
import sys.io.FileSeek;

class HPL
{
	private var magic:String = null;
	private var unk1:Int = -1;
	private var fileLen:Int = -1;

	public var name:String = null;
	public var paletteData(default, null):Vector<Int>;
    
	public function new(f:FileInput, name:String)
	{
		this.name = name;

		f.bigEndian = false;
		f.seek(0, FileSeek.SeekEnd);
		var realFileSize:Int = f.tell();
		f.seek(0, FileSeek.SeekBegin);
		
		if (f.readString(4) != "HPAL")
		{
			f.close();
			throw "Invalid HPL file!";
		}

		unk1 = f.readInt32();
		fileLen = f.readInt32();

		if (fileLen != realFileSize)
		{
			// If the filesize is wrong, we may have the wrong endian
			f.bigEndian = true;
			f.seek(-8, FileSeek.SeekCur);

			unk1 = f.readInt32();
			fileLen = f.readInt32();

			if (fileLen != realFileSize)
			{
				throw "Invalid palette file size!";
			}
		}

		f.seek(0x20, FileSeek.SeekBegin);
		
		paletteData = new Vector<Int>(0x100);
		
		for (i in 0...paletteData.length)
		{
			var argb:Int = f.readInt32();
			paletteData[i] = argb;
		}
	}
}