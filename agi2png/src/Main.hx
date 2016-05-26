package;

import easyconsole.Begin;
import easyconsole.End;
import format.png.Data;
import format.png.Tools;
import format.png.Writer;
import haxe.ds.Vector;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;
import sys.io.FileSeek;
class Main 
{
	static private var f:FileInput;
	static private var outDir:String;
	
	static function main()
	{
		Begin.init();
		Begin.usage = '${Path.withoutExtension(Path.withoutDirectory(Sys.executablePath()))} inFile outDir\n    inFile: The .agi file to convert. Can alternatively be a folder containing the files to convert\n    outDir: The folder to save the converted files to';
		Begin.functions = [null, null, checkArgs];
		Begin.parseArgs();
	}
	
	static private function checkArgs()
	{
		outDir = Begin.args[1];
		
		if (FileSystem.exists(outDir) && !FileSystem.isDirectory(outDir))
		{
			End.terminate(1, "outDir must be a directory!");
		}
		
		if (FileSystem.isDirectory(Begin.args[0]))
		{
			var files:Array<String> = FileSystem.readDirectory(Begin.args[0]);
			
			for (file in files)
			{
				if (Path.extension(file).toLowerCase() == "agi")
				{
					loadFile(Begin.args[0] + "/" + file);
				}
			}
		}
		else
		{
			loadFile(Begin.args[0]);
		}
		
		End.terminate(0, "Done");
	}
	
	static private function loadFile(path:String)
	{
		Sys.println("Converting " + path);
		f = File.read(path);
		f.bigEndian = false;
		
		//Header
		f.seek(0x10, FileSeek.SeekBegin);
		var bitDepth:Int = Std.int(32 / f.readByte());
		
		f.seek(0x18, FileSeek.SeekBegin);
		var width:Int = f.readUInt16();
		var height:Int = f.readUInt16();
		var palOff:Int = f.readInt32();
		var pixNum:Int = Std.int((width * height));
		var imgLen:Int = Std.int(pixNum / (8 / bitDepth));
		
		var b:Bytes = null;
		
		if (bitDepth == 32)
		{
			b = load32(width, height, pixNum);
		}
		else
		{
			b = loadPaletted(width, height, imgLen, palOff, bitDepth);
		}
		
		f.close();
		
		FileSystem.createDirectory(outDir);
		var filename:String = new Path(path).file;
		
		var dat:Data = Tools.build32ARGB(width, height, b);
		var o:FileOutput = File.write(outDir + "/" + filename + ".png");
		var w:Writer = new Writer(o);
		Sys.println("Saving " + outDir + "/" + filename + ".png");
		w.write(dat);
		o.close();
	}
	
	static private function loadPaletted(width:Int, height:Int, imgLen:Int, palOff:Int, bitDepth:Int):Bytes
	{
		//Palette
		f.seek(palOff, FileSeek.SeekBegin);
		
		var pal:Vector<Int> = new Vector<Int>(Std.int(Math.pow(2, bitDepth)));
		f.bigEndian = true;
		
		for (i in 0...pal.length)
		{
			var rgb:Int = f.readUInt24();
			var a:Int = f.readByte();
			a = (a != 0) ? 0xFF : a;
			var argb:Int = (a << 24) + rgb;
			
			if (bitDepth == 4 || Math.floor(i / 8) % 4 == 0 || Math.floor(i / 8) % 4 == 3) pal[i] = argb;
			else
			if (Math.floor(i / 8) % 4 == 1) pal[i + 8] = argb;
			else
			if (Math.floor(i / 8) % 4 == 2) pal[i - 8] = argb;
		}
		
		//Image
		f.seek(0x30, FileSeek.SeekBegin);
		
		var ob:BytesOutput = new BytesOutput();
		ob.bigEndian = true;
		
		for (i in 0...imgLen)
		{
			var b:Int = f.readByte();
			
			if (bitDepth == 4)
			{
				var p1:Int = b & 0x0F;
				var p2:Int = (b >> 4) & 0x0F;
				
				ob.writeInt32(pal[p1]);
				ob.writeInt32(pal[p2]);
			}
			else
			if (bitDepth == 8)
			{
				ob.writeInt32(pal[b]);
			}
		}
		
		return ob.getBytes();
	}
	
	static private function load32(width:Int, height:Int, pixNum:Int)
	{
		//Image
		f.seek(0x20, FileSeek.SeekBegin);
		
		var ob:BytesOutput = new BytesOutput();
		ob.bigEndian = true;
		
		trace(pixNum);
		
		for (i in 0...pixNum)
		{
			var rgb:Int = f.readUInt24();
			var a:Int = f.readByte();
			a = (a != 0) ? 0xFF : a;
			var argb:Int = (a << 24) + rgb;
			
			ob.writeInt32(argb);
		}
		
		return ob.getBytes();
	}
}