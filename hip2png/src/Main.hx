package ;

import easyconsole.Begin;
import easyconsole.End;
import format.png.Data;
import format.png.Tools;
import format.png.Writer;
import haxe.ds.Vector;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.io.Path;
import neko.Lib;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;
import sys.io.FileSeek;

class Main 
{
	private var f:FileInput;
	private var inDir:String;
	private var outDir:String;
	private var palf:FileInput;
	private var palette:Vector<Int>;
	
	public function new() 
	{
		Begin.init();
		Begin.usage = "Usage: hip2png inDir outDir\n    inDir: A folder containing the .hip files to convert\n    outDir: The folder to save the converted files to";
		Begin.functions = [null, null, checkArgs];
		Begin.parseArgs();
	}
	
	private function checkArgs()
	{
		
		inDir = Begin.args[0];
		
		if (FileSystem.exists(inDir) && !FileSystem.isDirectory(inDir))
		{
			End.terminate(1, "inDir must be a directory!");
		}
		
		inDir = Path.addTrailingSlash(inDir);
		
		outDir = Begin.args[1];
		
		if (FileSystem.exists(outDir) && !FileSystem.isDirectory(outDir))
		{
			End.terminate(1, "outDir must be a directory!");
		}
		
		outDir = Path.addTrailingSlash(outDir);
		
		loadPalette(inDir);
		
		var files:Array<String> = FileSystem.readDirectory(inDir);
		
		for (file in files)
		{
			if (file.substr( -4, 4) == ".hip")
			{
				convertHIP(inDir + file);
			}
		}
		
		End.terminate(0, "Done");
	}
	
	private function loadPalette(dir:String)
	{
		var palPath:String = null;
		var files:Array<String> = FileSystem.readDirectory(inDir);
		
		for (file in files)
		{
			if (file.substring(file.length - 9) == '00_00.hpl')
			{
				palPath = Path.join([inDir, file]);
			}
		}
		
		if (palPath == null)
		{
			End.terminate(1, "Could not locate palette file!");
		}
		
		Sys.println('Using palette $palPath');
		
		var palf:FileInput = File.read(palPath);
		
		if (palf.readString(4) != "HPAL")
		{
			palf.close();
			f.close();
			End.terminate(1, "Invalid HPL file!");
		}
		
		palf.seek(0x20, FileSeek.SeekBegin);
		
		palette = new Vector<Int>(0x100);
		
		for (i in 0...palette.length)
		{
			var a:Int = palf.readByte();
			var r:Int = palf.readByte();
			var g:Int = palf.readByte();
			var b:Int = palf.readByte();
			
			var argb:Int = (a << 24) + (r << 16) + (g << 8) + b;
			palette[i] = argb;
		}
		
		palf.close();
	}
	
	private function convertHIP(path:String)
	{
		Sys.println('Converting $path');
		
		//Header
		f = File.read(path);
		f.bigEndian = true;
		
		if (f.readString(4) != "HIP" + String.fromCharCode(0))
		{
			f.close();
			End.terminate(1, "Invalid HIP file!");
		}
		
		f.readInt32();
		var len:Int = f.readInt32();
		f.readInt32();
		var width:Int = f.readInt32();
		var height:Int = f.readInt32();
		var flags:Int = f.readInt32();
		f.readInt32();
		
		if (flags >> 16 == 0x2001)
		{
			width = f.readInt32();
			height = f.readInt32();
			f.seek(0x18, FileSeek.SeekCur);
		}
		
		//Data
		f.seek(0x400, FileSeek.SeekCur);
		
		var bpp:Int = 1;
		var bpc:Int = 4;
		
		var compLen:Int = len - f.tell();
		var decompLen:Int = width * height * bpp;
		
		var b:Bytes = Bytes.alloc(decompLen);
		var pos:Int = 0;
		
		for (i in 0...Std.int(compLen / 2))
		{
			var p:Int = f.readByte();
			var n:Int = f.readByte();
			
			for (j in 0...n)
			{
				b.set(pos, p);
				pos++;
			}
		}
		
		f.close();
		
		if (pos != decompLen)
		{
			End.terminate(1, "Invalid decompressed length!");
		}
		
		//Make complete data
		var out:BytesOutput = new BytesOutput();
		out.bigEndian = true;
		
		pos = 0;
		while (pos < b.length)
		{
			try
			{
				out.writeInt32(palette[b.get(pos)]);
			}
			catch (e:String)
			{
				trace(e);
				trace(StringTools.hex(pos));
			}
			
			pos++;
		}
		
		//Save to png
		FileSystem.createDirectory(outDir);
		
		var filename:String = new Path(path).file;
		
		var pngDat:Data = Tools.build32ARGB(width, height, out.getBytes());
		var w:Writer = new Writer(File.write(outDir + "/" + filename + ".png"));
		Sys.println("Saving " + outDir + "/" + filename + ".png");
		w.write(pngDat);
	}
	
	private function getCharID(filename:String):String
	{
		var idPattern:EReg = ~/[A-Z]+[0-9]/i;
		if (!idPattern.match(filename))
		{
			End.terminate(1, 'Invalid name format: cannot detect character ID');
		}
		
		var charID = idPattern.matched(0);
		idPattern = ~/[A-Z]+/i;
		idPattern.match(charID);
		charID = idPattern.matched(0);
		
		return charID;
	}
	
	static function main()
	{
		new Main();
	}
}