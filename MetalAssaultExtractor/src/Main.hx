package ;

import console.Begin;
import console.End;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.zip.InflateImpl;
import neko.Lib;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileSeek;

class Main 
{
	static private var f:FileInput;
	static private var fileLength:Int;
	
	static function main() 
	{
		Begin.init();
		Begin.usage = "Usage: MetalAssaultExtractor inFile\n    inFile: The mas.cvf file";
		Begin.functions = [null, loadFile];
		Begin.parseArgs();
	}
	
	static private function loadFile()
	{
		f = File.read(Begin.args[0]);
		f.seek(0, FileSeek.SeekEnd);
		fileLength = f.tell();
		f.seek(0, FileSeek.SeekBegin);
		
		if (f.readString(11) != "SFILESYSTEM" || f.readByte() != 0)
		{
			f.close();
			End.anyKeyExit(1, "Invalid file!");
		}
		
		var root:MADir = new MADir();
		root.path = Sys.getCwd() + "metal_assault_extracted";
		root.start = 0;
		root.end = fileLength;
		var currDir:MADir = root;
		
		Sys.println("Parsing archive...");
		
		readUntilEnd(root);
		
		Sys.println("Archive parsed!");
		Sys.println("Extracting files...");
		
		recursiveWrite(root);
		
		f.close();
		
		End.anyKeyExit(0, "Done! Press any key to exit");
	}
	
	static private function readUntilEnd(parent:MADir)
	{
		while(f.tell() < parent.end)
		{
			var type:Int = f.readInt32();
			
			if (type == 0)
			{
				var dir:MADir = new MADir();
				var name:String = f.readString(264);
				var buf:StringBuf = new StringBuf();
				buf.addChar(0);
				name = name.substring(0, name.indexOf(buf.toString()));
				dir.path = parent.path + "/" + name;
				
				dir.start = f.readInt32();
				dir.end = f.readInt32();
				
				if (dir.end == 0) dir.end = fileLength;
				
				readUntilEnd(dir);
				
				parent.dirs.push(dir);
			}
			else
			if (type == 1)
			{
				var file:MAFile = new MAFile();
				var name:String = f.readString(256);
				var buf:StringBuf = new StringBuf();
				buf.addChar(0);
				name = name.substring(0, name.indexOf(buf.toString()));
				file.path = parent.path + "/" + name;
				
				file.zsize = f.readInt32();
				file.size = f.readInt32();
				file.unk = f.readInt32();
				file.endOff = f.readInt32();
				file.offset = f.tell();
				f.seek(file.zsize, FileSeek.SeekCur);
				
				parent.files.push(file);
			}
			else
			{
				trace("unknown type: " + type);
			}
		}
	}
	
	static private function recursiveWrite(parent:MADir)
	{
		for (i in parent.dirs)
		{
			if (i.path.charAt(i.path.length - 1) == ".")
			{
				if (i.path.charAt(i.path.length - 2) == ".")
				{
					//File.saveContent(parent.path + "/" + "twoDots.txt", "bar");
					continue;
				}
				else
				{
					//File.saveContent(parent.path + "/" + "oneDot.txt", "foo");
					continue;
				}
			}
			
			FileSystem.createDirectory(i.path);
			
			Sys.println("Created directory: " + i.path);
			
			recursiveWrite(i);
		}
		
		for (i in parent.files)
		{
			f.seek(i.offset, FileSeek.SeekBegin);
			var bytes:Bytes = InflateImpl.run(f, i.zsize);
			File.saveBytes(i.path, bytes);
			
			Sys.println("Extracted file: " + i.path);
		}
	}
}