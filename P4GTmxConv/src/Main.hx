package;
import format.png.Tools;
import format.png.Writer;
import haxe.ds.Vector;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;
import sys.io.FileSeek;

class Main 
{
	public function new()
	{
		var files:Array<String> = FileSystem.readDirectory('.');
		
		for (f in files)
		{
			if (Path.extension(f) == 'bin' || Path.extension(f) == 'tmx')
			{
				Sys.println('Loading $f');
				loadFile(f);
			}
			else
			if (Path.extension(f) == 'tga')
			{
				Sys.println('Loading $f');
				loadTGA(f);
			}
		}
		
		Sys.print('Done!');
		Sys.getChar(false);
	}
	
	private function loadFile(fPath:String)
	{
		var fName:String = Path.withoutDirectory(fPath);
		var f:FileInput = File.read(fPath);
		f.seek(8, FileSeek.SeekBegin);
		
		if (f.readString(4) == 'TMX0')
		{
			f.seek(0, FileSeek.SeekBegin);
			convertTMX(fName, new BytesInput(f.readAll()));
			f.close();
			return;
		}
		
		f.seek(0, FileSeek.SeekBegin);
		var fNum:Int = f.readInt32();
		
		for (i in 0...fNum)
		{
			var name:String = StringTools.replace(f.readString(0x20), String.fromCharCode(0), '');
			var size:Int = f.readInt32();
			
			convertTMX(name, new BytesInput(f.read(size)));
		}
		
		f.close();
	}
	
	private function convertTMX(name:String, b:BytesInput)
	{
		var unk:Int = b.readInt32();
		var size:Int = b.readInt32();
		
		if (b.readString(4) != 'TMX0')
		{
			Sys.println('Invalid TMX!!');
			return;
		}
		
		b.position += 6;
		
		var width:Int = b.readInt16();
		var height:Int = b.readInt16();
		
		b.position += 0x2A;
		
		var linPalette:Vector<Int> = new Vector<Int>(0x100);
		
		b.bigEndian = true;
		for (i in 0...linPalette.length)
		{
			linPalette[i] = b.readUInt24();
			var a:Int = b.readByte();
			
			if (a <= 0) a = 0;
			else if (a >= 0x80) a = 0xFF;
			else a = Std.int(0xFF * (a / 0x80));
			
			linPalette[i] += a << 24;
		}
		
		var palette:Vector<Int> = new Vector<Int>(0x100);
		
		var ntx:Int = Std.int(16 / 8);
		var nty:Int = Std.int(16 / 2);
		var i:Int = 0;
		
		for (ty in 0...nty)
		{
			for (tx in 0...ntx)
			{
				for (y in 0...2)
				{
					for (x in 0...8)
					{
						palette[(ty * 2 + y) * 16 + (tx * 8 + x)] = linPalette[i++];
					}
				}
			}
		}
		
		var pixNum:Int = width * height;
		var pixOut:BytesOutput = new BytesOutput();
		pixOut.bigEndian = true;
		
		for (i in 0...pixNum)
		{
			pixOut.writeInt32(palette[b.readByte()]);
		}
		
		savePNG(name, pixOut.getBytes(), width, height);
		
		b.position -= pixNum;
		pixOut = new BytesOutput();
		pixOut.bigEndian = true;
		
		for (i in 0...pixNum)
		{
			pixOut.writeInt32((palette[b.readByte()] & 0xFFFFFF) + (0xFF << 24));
		}
		
		savePNG(Path.withoutExtension(name) + '_noalpha', pixOut.getBytes(), width, height);
	}
	
	private function loadTGA(fPath:String)
	{
		var fName:String = Path.withoutDirectory(fPath);
		var f:FileInput = File.read(fPath);
		f.seek(0xC, FileSeek.SeekBegin);
		
		var width:Int = f.readInt16();
		var height:Int = f.readInt16();
		f.readInt16();
		
		var palette:Vector<Int> = new Vector<Int>(0x100);
		
		for (i in 0...palette.length)
		{
			palette[i] = f.readUInt24();
			var a:Int = f.readByte();
			
			//if (i > 0 && a == 0) a = 0xFF;
			
			palette[i] += a << 24;
		}
		
		f.seek(0x420, FileSeek.SeekBegin);
		
		var pixNum:Int = width * height;
		var pixOut:BytesOutput = new BytesOutput();
		pixOut.bigEndian = true;
		
		for (i in 0...pixNum)
		{
			pixOut.writeInt32(palette[f.readByte()]);
		}
		
		savePNG(fName, pixOut.getBytes(), width, height);
	}
	
	private function savePNG(name:String, b:Bytes, width:Int, height:Int)
	{
		var outPath:String = 'extracted';
		FileSystem.createDirectory(outPath);
		outPath += '/' + Path.withoutExtension(name) + '.png';
		
		var o:FileOutput = File.write(outPath);
		var w:Writer = new Writer(o);
		w.write(Tools.build32ARGB(width, height, b));
		o.close();
		
		Sys.println('$outPath saved!');
	}
	
	private function flip(b:Bytes, width:Int, height:Int):Bytes
	{
		var input:BytesInput = new BytesInput(b);
		input.bigEndian = true;
		var out:BytesOutput = new BytesOutput();
		out.bigEndian = true;
		input.position = input.length;
		
		for (y in 0...height)
		{
			input.position -= width * 4;
			
			for (x in 0...width)
			{
				out.writeInt32(input.readInt32());
			}
		}
		
		trace(StringTools.hex(input.length));
		trace(StringTools.hex(out.length));
		
		return out.getBytes();
	}
	
	static function main()
	{
		new Main();
	}
}