package ;

import easyconsole.Begin;
import easyconsole.End;
import format.png.Data;
import format.png.Tools;
import format.png.Writer;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileSeek;

class Main 
{
	static private var f:FileInput;
	static private var outDir:String;
	
	static function main() 
	{
		Begin.init();
		Begin.usage = "Usage: bstga2png inFile outDir\n    inFile: The .bstga file to convert. Can alternatively be a folder containing the files to convert\n    outDir: The folder to save the converted files to";
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
				if (file.substr( -4, 4) == ".bstga")
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
		
		f.seek(0x10, FileSeek.SeekBegin);
		var width:Int = f.readInt16();
		var height:Int = f.readInt16();
		var offset:Int = f.readInt32();
		var length:Int = f.readInt32();
		f.readString(8);
		var palOff:Int = f.readInt32();
		var palLen:Int = f.readInt32();
		
		f.seek(offset, FileSeek.SeekBegin);
		var pxlBytes:Bytes = Bytes.alloc(length);
		f.readBytes(pxlBytes, 0, length);
		
		var pixelVals:Array<Int> = new Array<Int>();
		
		for (i in 0...pxlBytes.length)
		{
			var byte:Int = pxlBytes.get(i);
			pixelVals.push(byte & 0x0F);
			pixelVals.push((byte & 0xF0) >> 4);
		}
		
		f.seek(palOff, FileSeek.SeekBegin);
		f.bigEndian = false;
		
		var palette:Array<Int> = new Array<Int>();
		var colNum:Int = Std.int(palLen / 2);
		
		for(i in 0...colNum)
		{
			var col:Int = f.readInt16();
			var a:Int = ((col & 0x8000) >> 15) * 0xFF;
			var b:Int = (col & 0x7C00) >> 7;
			var g:Int = (col & 0x3E0) >> 2;
			var r:Int = (col & 0x1F) << 3;
			var argb:Int = (a << 24) + (r << 16) + (g << 8) + b;
			palette.push(argb);
		}
		
		f.bigEndian = false;
		f.close();
		
		var pixelsOut:BytesOutput = new BytesOutput();
		pixelsOut.bigEndian = true;
		
		for (val in pixelVals)
		{
			pixelsOut.writeInt32(palette[val]);
		}
		
		FileSystem.createDirectory(outDir);
		
		var filename:String = new Path(path).file;
		
		var pngDat:Data = Tools.build32ARGB(width, height, pixelsOut.getBytes());
		var w:Writer = new Writer(File.write(outDir + "/" + filename + ".png"));
		Sys.println("Saving " + outDir + "/" + filename + ".png");
		w.write(pngDat);
		pixelsOut.close();
	}
}