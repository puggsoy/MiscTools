package ;

import console.Begin;
import console.End;
import format.png.Data;
import format.png.Reader;
import format.png.Tools;
import format.png.Writer;
import haxe.crypto.BaseCode;
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
	static private var outDir:String;
	
	static function main() 
	{
		Begin.init();
		Begin.usage = "Usage: toysolconv inFile outDir [-t]\n    inFile: The file to convert. Can alternatively be a folder containing the files to convert\n    outDir: The folder to save the converted files to\n    -t: Converts to a .tgab, instead of .pngb. Only applies when the input file(s) are .png, otherwise it's ignored";
		Begin.functions = [null, null, checkArgs];
		Begin.parseArgs();
	}
	
	static private function checkArgs()
	{
		outDir = Begin.args[1];
		
		if (!FileSystem.exists(Begin.args[0]))
		{
			End.terminate(1, "inFile must be a valid file or folder");
		}
		
		if (FileSystem.exists(outDir) && !FileSystem.isDirectory(outDir))
		{
			End.terminate(2, "outDir must be a directory!");
		}
		
		if (FileSystem.isDirectory(Begin.args[0]))
		{
			var files:Array<String> = FileSystem.readDirectory(Begin.args[0]);
			
			for (file in files)
			{
				if (file.substr( -5, 5) == ".pngb" || file.substr( -5, 5) == ".tgab")
				{
					toPNG(Begin.args[0] + "/" + file);
				}
				else
				if (file.substr( -4, 4) == ".png")
				{
					fromPNG(Begin.args[0] + "/" + file);
				}
			}
		}
		else
		{
			if (Begin.args[0].substr( -5, 5) == ".pngb" || Begin.args[0].substr( -5, 5) == ".tgab")
			{
				toPNG(Begin.args[0]);
			}
			else
			if (Begin.args[0].substr( -4, 4) == ".png")
			{
				fromPNG(Begin.args[0]);
			}
		}
		
		End.terminate(0, "Done");
	}
	
	static private function toPNG(path:String)
	{
		Sys.println("Converting " + path);
		var f:FileInput = File.read(path);
		f.bigEndian = false;
		
		var magic:String = "BE79E8842153696742210200BE79E884".toLowerCase();
		var magicTest:Bytes = Bytes.alloc(16);
		f.readBytes(magicTest, 0, 16);
		
		if (magicTest.toHex() != magic)
		{
			f.close();
			Sys.println("Invalid header!");
			return;
		}
		
		f.seek(0x66, FileSeek.SeekBegin);
		
		if (f.readInt32() != 0)
		{
			f.close();
			Sys.println("Unsupported format");
			return;
		}
		
		f.seek(0x60, FileSeek.SeekBegin);
		
		var width:Int = f.readInt16();
		var height:Int = f.readInt16();
		
		f.seek(0x7C, FileSeek.SeekBegin);
		
		var length:Int = f.readInt32();
		var pxlBytes:Bytes = f.read(length);
		
		f.close();
		
		FileSystem.createDirectory(outDir);
		
		var filename:String = new Path(path).file;
		
		var pngDat:Data = Tools.build32BGRA(width, height, pxlBytes);
		var o:FileOutput = File.write(outDir + "/" + filename + ".png");
		var w:Writer = new Writer(o);
		w.write(pngDat);
		o.close();
		Sys.println("Saved " + outDir + "/" + filename + ".png");
	}
	
	static private function fromPNG(path:String)
	{
		Sys.println("Converting " + path);
		var i:FileInput = File.read(path);
		var r:Reader = new Reader(i);
		var pngDat:Data = r.read();
		i.close();
		
		i = File.read("header_template.bin");
		var outBytes:BytesOutput = new BytesOutput();
		outBytes.bigEndian = false;
		outBytes.write(i.read(0x60));
		
		var pngHead:Header = Tools.getHeader(pngDat);
		outBytes.writeInt16(pngHead.width);
		outBytes.writeInt16(pngHead.height);
		i.seek(4, FileSeek.SeekCur);
		outBytes.write(i.read(0x18));
		
		var pxlBytes:Bytes = Tools.extract32(pngDat);
		outBytes.writeInt32(pxlBytes.length);
		outBytes.write(pxlBytes);
		
		var filename:String = new Path(path).file;
		var extension:String = ".pngb";
		
		if (Begin.args.length == 3 && Begin.args[2] == "-t")
		{
			extension = ".tgab";
		}
		
		var o:FileOutput = File.write(outDir + "/" + filename + extension);
		o.write(outBytes.getBytes());
		o.close();
		Sys.println("Saved " + outDir + "/" + filename + extension);
	}
}