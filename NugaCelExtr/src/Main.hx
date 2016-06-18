package;

import easyconsole.End;
import format.gz.Reader;
import format.png.Data;
import format.png.Tools;
import format.png.Writer;
import haxe.ds.Vector;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.io.Eof;
import haxe.io.Input;
import haxe.io.Path;
import neko.Lib;
import easyconsole.Begin;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;
import sys.io.FileSeek;

class Main 
{
	private var inFile:String;
	private var noAlpha:Bool = false;
	
	public function new()
	{
		Begin.init();
		Begin.usage = 'Usage: ${Path.withoutExtension(Path.withoutDirectory(Sys.executablePath()))} inFile\n    inFile: The .uni file to extract';//\n    [ -a]: Optional alpha flag, include to DISABLE alpha\n';
		Begin.functions = [null, loadFile];
		Begin.parseArgs();
	}
	
	private function loadFile()
	{
		if (!FileSystem.exists(Begin.args[0]))
		{
			Sys.println('Can\'t find file ${Begin.args[0]}!');
			End.terminate(1);
		}
		
		inFile = Path.withoutDirectory(Begin.args[0]);
		
		if (Begin.args.length > 1) noAlpha = (Begin.args[1] == '-a');
		
		var f:FileInput = File.read(Begin.args[0]);
		
		f.bigEndian = true;
		
		var magic:Int = f.readInt32();
		f.seek(0, FileSeek.SeekBegin);
		
		switch(magic)
		{
			case 0xA00:
				f.seek(0xA000, FileSeek.SeekBegin);
				compressed(f, true);
			case 0x1F8B0808: compressed(f, false);
			case 0x554E4932: uncompressedUNI(f);
			default: uncompressed(f);
		}
		
		End.anyKeyExit(0, "Done!");
	}
	
	private function compressed(f:FileInput, art2:Bool)
	{
		f.bigEndian = true;
		
		var end:Bool = false;
		
		while (!end)
		{
			var off:Int = f.tell();
			f.readInt32();
			
			end = !searchForGZ(f);
			
			var len:Int = f.tell() - off;
			
			f.seek(off, FileSeek.SeekBegin);
			
			var compressed:Bytes = Bytes.alloc(len);
			f.readBytes(compressed, 0, len);
			var bi:BytesInput = new BytesInput(compressed);
			var ungz = new Reader(bi).read();
			var decompressed:Bytes = ungz.data;
			
			if (art2) convertART2(new BytesInput(decompressed), Path.withoutExtension(ungz.file));
			else extractCO2R(new BytesInput(decompressed), Path.withoutExtension(ungz.file));
		}
	}
	
	private function uncompressed(f:FileInput)
	{
		var groupNum:Int = 0;
		
		var end:Bool = !search(f, 'CO2R');
		
		while (search(f, 'CO2R'))
		{
			var off:Int = f.tell() - 8;
			
			search(f, 'CO2R');
			f.seek( -8, FileSeek.SeekCur);
			
			var len:Int = f.tell() - off;
			
			f.seek(off, FileSeek.SeekBegin);
			
			var b:Bytes = Bytes.alloc(len);
			f.readBytes(b, 0, len);
			var bi:BytesInput = new BytesInput(b);
			
			groupNum++;
			extractCO2R(bi, '$groupNum');
		}
	}
	
	private function uncompressedUNI(f:FileInput)
	{
		f.bigEndian = false;
		f.seek(8, FileSeek.SeekBegin);
		var imgNum:Int = f.readInt32();
		f.seek(0x10, FileSeek.SeekBegin);
		var baseChunkOff:Int = f.readInt32();
		
		var chunk:Int = 0x800;
		f.seek(chunk, FileSeek.SeekBegin);
		
		for (i in 0...imgNum)
		{
			f.readInt32();//file number
			var chunkOff:Int = f.readInt32();
			f.readInt32();//number of chunks for this file
			var size:Int = f.readInt32();
			
			var tmp:Int = f.tell();
			var offset:Int = (chunkOff + baseChunkOff) * chunk;
			f.seek(offset, FileSeek.SeekBegin);
			
			var bi:BytesInput = new BytesInput(f.read(size));
			convertART2(bi, inFile);
			
			f.seek(tmp, FileSeek.SeekBegin);
		}
	}
	
	private function convertART2(bi:BytesInput, fName:String)
	{
		bi.bigEndian = false;
		
		var magic:String = bi.readString(4);
		if (magic != 'ART2') End.anyKeyExit(1, '**bad art2 header** - should be "ART2" not "$magic"');
		if (bi.readInt32() != 8) trace('not 8 in $fName');
		
		var width:Int = bi.readInt32();
		var height:Int = bi.readInt32();
		var len:Int = width * height;
		var name:String = bi.readString(0x0F).split(String.fromCharCode(0))[0];
		
		bi.position = 0x20 + len;
		
		var tmpPalette:Vector<Int> = new Vector<Int>(0x100);
		bi.bigEndian = true;
		
		for (i in 0...tmpPalette.length)
		{
			var rgba:Int = bi.readInt32();
			var a:Int = rgba & 0xFF;
			a = Std.int(Math.min(a * 2, 0xFF));
			var rgb:Int = (rgba >> 8) & 0xFFFFFF;
			//if (a != 0 || noAlpha) a = 0xFF;
			var argb:Int = (a << 24) + rgb;
			
			tmpPalette[i] = argb;
		}
		
		var palette:Vector<Int> = new Vector<Int>(tmpPalette.length);
		
		var newPos:Int = 0;
		var oldPos:Int = 0;
		
		for (tile in 0...0x10)
		{
			for (y in 0...2)
			{
				for (x in 0...8)
				{
					palette[newPos++] = tmpPalette[oldPos + x];
				}
				
				if (y == 0) oldPos += 16;
			}
			
			if (tile % 2 == 0) oldPos -= 8;
			else oldPos += 8;
		}
		
		bi.position = 0x20;
		
		var bo:BytesOutput = new BytesOutput();
		bo.bigEndian = true;
		
		for (i in 0...len) bo.writeInt32(palette[bi.readByte()]);
		
		var outDir:String = '${Path.withoutExtension(inFile)}';
		
		FileSystem.createDirectory(outDir);
		
		var filePath:String = '$outDir/$name.png';
		
		var dat:Data = Tools.build32ARGB(width, height, bo.getBytes());
		var o:FileOutput = File.write(filePath);
		new Writer(o).write(dat);
		o.close();
		
		trace(filePath);
	}
	
	private function extractCO2R(bi:BytesInput, name:String)
	{
		bi.bigEndian = false;
		bi.position += 0x4;
		
		if (bi.readString(4) != 'CO2R') End.anyKeyExit(1, '**bad co2r header**');
		
		bi.position += 0x10;
		var imgNum:Int = bi.readInt32();
		
		search(bi, 'LTMR');
		bi.position += 0x8;
		
		trace('--$name--');
		
		for (i in 0...imgNum) extractSingleImg(bi, i, name);
	}
	
	private function extractSingleImg(bi:BytesInput, imgNum:Int, groupName:String)
	{
		bi.bigEndian = false;
		var len:Int = bi.readInt32();
		bi.position += 0x8;
		var width:Int = bi.readInt32();
		var height:Int = bi.readInt32();
		bi.position += 0xC;
		
		var palette:Vector<Int> = new Vector<Int>(16);
		bi.bigEndian = true;
		
		for (j in 0...2)
		{
			for (i in 0...8)
			{
				var rgba:Int = bi.readInt32();
				var a:Int = rgba & 0xFF;
				a = Std.int(Math.min(a * 2, 0xFF));
				var rgb:Int = (rgba >> 8) & 0xFFFFFF;
				//if (a != 0 || noAlpha) a = 0xFF;
				var argb:Int = (a << 24) + rgb;
				
				palette[i + (j * 8)] = argb;
			}
			
			if(j == 0) bi.position += 0x20;
		}
		
		bi.position += 0x3A0;
		
		var bo:BytesOutput = new BytesOutput();
		bo.bigEndian = true;
		
		for (i in 0...len)
		{
			var b:Int = bi.readByte();
			bo.writeInt32(palette[b & 0xF]);
			bo.writeInt32(palette[(b >> 4) & 0xF]);
		}
		
		imgNum++;
		
		var outDir:String = '${Path.withoutExtension(inFile)}/$groupName';
		
		FileSystem.createDirectory(outDir);
		
		var numName:String = StringTools.lpad('$imgNum', '0', 4);
		var filePath:String = '$outDir/$numName.png';
		
		var dat:Data = Tools.build32ARGB(width, height, bo.getBytes());
		var o:FileOutput = File.write(filePath);
		new Writer(o).write(dat);
		o.close();
		
		trace(filePath);
	}
	
	private function searchForGZ(f:FileInput):Bool
	{
		while (f.readInt32() != 0x1F8B0808)
		{
			f.seek( -3, FileSeek.SeekCur);
			
			try
			{
				f.readUntil(0x1F);
				f.seek( -1, FileSeek.SeekCur);
			}
			catch (e:Eof)
			{
				f.seek(0, FileSeek.SeekEnd);
				return false;
			}
		}
		
		f.seek( -4, FileSeek.SeekCur);
		
		return true;
	}
	
	private function search(i:Input, s:String, file:Bool = false):Bool
	{
		var firstChar:Int = s.charCodeAt(0);
		
		if (Type.getClass(i) == FileInput)
		{
			var f:FileInput = cast(i, FileInput);
			
			while (f.readString(s.length) != s)
			{
				f.seek( -(s.length - 1), FileSeek.SeekCur);
				
				try
				{
					f.readUntil(firstChar);
				}
				catch (e:Eof)
				{
					f.seek(0, FileSeek.SeekEnd);
					return false;
				}
				
				f.seek( -1, FileSeek.SeekCur);
			}
		}
		else
		{
			var bi:BytesInput = cast(i, BytesInput);
			
			while (bi.readString(s.length) != s)
			{
				bi.position -= s.length - 1;
				
				try
				{
					bi.readUntil(firstChar);
				}
				catch (e:Eof)
				{
					bi.position = bi.length - 1;
					return false;
				}
				
				bi.position--;
			}
		}
		
		return true;
	}
	
	static function main() 
	{
		new Main();
	}
}