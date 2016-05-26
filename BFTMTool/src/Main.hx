package ;

import format.tools.Inflate;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.io.Path;
import haxe.Log;
import neko.Lib;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;

/**
 * ...
 * @author Puggsoy
 */

class Main 
{
	private static var _create:Bool;
	private static var _extract:Bool;
	private static var _overwrite:Bool;
	
	private static var _bftmPath:Path;
	private static var _dir:Path;
	
	private static var _bftm:BFTM;
	
	static function main() 
	{
		_overwrite = true;
		_extract = true;
		_create = false;
		
		var args:Array<String> = Sys.args();
		var argCount:Int = 0;
		
		if (args.length > 0)
		{
			if (args[argCount] == "-c")
			{
				_extract = false;
				_create = true;
				argCount++;
			}
			
			if (args[argCount] == "-p")
			{
				_overwrite = false;
				
				argCount++;
			}
			
			_bftmPath = new Path(FileSystem.fullPath(args[argCount]));
			
			if (_bftmPath.ext != "bftm")
			{
				Sys.println("File must have the .bftm extension!");
				Sys.exit(2);
			}
			if (!FileSystem.exists(_bftmPath.toString()) && !_create)
			{
				printHelp();
			}
			
			argCount++;
			
			if (args[argCount] != null)
			{
				_dir = new Path(FileSystem.fullPath(args[argCount]));
			}
			else
			if(_create)
			{
				printHelp();
			}
			else
			{
				_dir = new Path(_bftmPath.dir + "/extracted");
			}
			
			if (_extract)
			{
				extractBFTM();
			}
			else
			{
				createBFTM();
			}
		}
		else
		{
			printHelp();
		}
	}
	
	static private function extractBFTM()
	{
		Sys.println("Extracting files");
		
		_bftm = new BFTM();
		_bftm.unpack(_bftmPath);
		
		createDirectoryRecursive(_dir.toString());
		
		var out:FileOutput;
		var outBytes:Bytes;
		
		for (entry in _bftm.entries)
		{
			if (!FileSystem.exists(_dir.toString() + "/" + entry.name) || _overwrite)
			{
				Sys.println("saving " + entry.name);
				
				var output:BytesOutput = new BytesOutput();
				output.writeBytes(_bftm.bytes, entry.offset, entry.size);
				outBytes = output.getBytes();
				
				if (new Path(entry.name).ext == "xml")
				{
					outBytes = Inflate.run(outBytes);
				}
				
				createDirectoryRecursive(_dir.toString() + "/" + new Path(entry.name).dir);
				
				out = File.write(_dir.toString() + "/" + entry.name);
				out.writeBytes(outBytes, 0, outBytes.length);
				out.close();
			}
		}
		
		Sys.println("All files extracted!");
	}
	
	static private function createBFTM()
	{
		Sys.println("Creating archive");
		
		_bftm = new BFTM();
		_bftm.pack(_dir.toString());
		
		var out:FileOutput = File.write(_bftmPath.toString());
		out.writeBytes(_bftm.bytes, 0, _bftm.bytes.length);
		out.close();
		
		Sys.println("Archive created!");
	}
	
	static private function printHelp()
	{
		Sys.println("Usage: BFTMTool [-c] [-p] bftm [dir]\nOptions:\n    -c: Create bftm. If omitted it will extract\n    -p: Prevent files from being overwritten (unused when creating)\n    bftm: The bftm file to create/extract from\n    dir: When creating this is the directory that will be the root of the created bftm, and it is required. When extracting this is the directory where the bftm will be extracted to, and if it is omitted it will be set to a subfolder of where the bftm is located.");
		Sys.getChar(false);
		Sys.exit(1);
	}
	
	static private function createDirectoryRecursive(pathString:String)
	{
		try
		{
			var path:Path = new Path(pathString);
			
			try
			{
				if (FileSystem.isDirectory(path.toString()))
				{
					return true;
				}
			}
			catch (e:Dynamic)
			{
				if (createDirectoryRecursive(path.dir))
				{
					FileSystem.createDirectory(path.toString());
				}
				else
				{
					return false;
				}
			}
			
			return true;
		}
		catch (e:Dynamic)
		{
			Sys.println(e);
			return false;
		}
	}
}