package ;

import console.Begin;
import console.End;
import format.png.Data;
import format.png.Tools;
import format.png.Writer;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.io.Path;
import neko.Lib;
import openfl.display.BitmapData;
import openfl.utils.ByteArray;
import openfl.Vector;
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
		Begin.usage = "Usage: gxt2png inFile outDir\n    inFile: The .gxt file to convert. Can alternatively be a folder containing the files to convert\n    outDir: The folder to save the converted files to";
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
				if (file.substr( -4, 4) == ".gxt")
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
		
		if (f.readString(0x0C) != "XXG.01.0MIG.")
		{
			f.close();
			End.terminate(1, "Invalid header!");
		}
		
		var bpp:Int = 0;
		
		f.seek(0x10, FileSeek.SeekBegin);
		
		var bppFlag:Int = f.readByte();
		
		if (bppFlag == 0x80)
		{
			bpp = 4;
		}
		else
		if (bppFlag == 0x40)
		{
			bpp = 8;
		}
		else
		{
			f.close();
			End.terminate(2, "Unknown pixel flag " + StringTools.hex(bppFlag, 2));
		}
		
		f.seek(0x44, FileSeek.SeekBegin);
		var len:Int = f.readInt32();
		
		f.seek(0x80, FileSeek.SeekBegin);
		var pxlBytes:Bytes = Bytes.alloc(len);
		f.readBytes(pxlBytes, 0, len);
		
		var pixelVals:Array<Int> = new Array<Int>();
		
		for (i in 0...pxlBytes.length)
		{
			var byte:Int = pxlBytes.get(i);
			
			if (bpp == 4)
			{
				pixelVals.push(byte & 0x0F);
				pixelVals.push((byte & 0xF0) >> 4);
			}
			else
			{
				pixelVals.push(byte);
			}
		}
		
		f.seek(0x80 + len + 0x40, FileSeek.SeekBegin);
		f.bigEndian = true;
		
		var palette:Array<Int> = new Array<Int>();
		
		while (true)
		{
			var rgba:Int = f.readInt32();
			var argb:Int = ((rgba & 0xFF) << 24) + ((rgba & 0xFFFFFF00) >>> 8);
			palette.push(argb);
			
			if (bpp == 4 && palette.length == 0x10)
			{
				break;
			}
			else
			if (bpp == 8 && palette.length == 0x100)
			{
				break;
			}
		}
		
		f.bigEndian = false;
		
		var pixelsOut:BytesOutput = new BytesOutput();
		pixelsOut.bigEndian = true;
		
		for (val in pixelVals)
		{
			pixelsOut.writeInt32(palette[val]);
		}
		
		f.seek(0x10, FileSeek.SeekBegin);
		f.seek(f.readInt32() + 0x20, FileSeek.SeekBegin);
		
		var w:Int = f.readInt32();
		var h:Int = f.readInt32();
		
		f.close();
		
		FileSystem.createDirectory(outDir);
		
		var filename:String = new Path(path).file;
		
		var pngDat:Data = Tools.build32ARGB(w, h, pixelsOut.getBytes());
		var w:Writer = new Writer(File.write(outDir + "/" + filename + ".png"));
		Sys.println("Saving " + outDir + "/" + filename + ".png");
		w.write(pngDat);
	}
}