package;

import easyconsole.Begin;
import easyconsole.End;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.io.Path;
import neko.Lib;
import sys.FileSystem;
import sys.io.File;

class Main 
{
	public function new() 
	{
		Begin.init();
		Begin.usage = "Usage: SDDtoDDS inDir\n    inDir: A folder containing the .dds_ files to convert";
		Begin.functions = [null, checkArgs, checkArgs];
		Begin.parseArgs();
	}
	
	private function checkArgs()
	{
		var inDir:String = Begin.args[0];
		
		if (!FileSystem.exists(inDir))
		{
			End.terminate(1, "inDir must exist!");
		}
		
		if (FileSystem.exists(inDir) && !FileSystem.isDirectory(inDir))
		{
			End.terminate(1, "inDir must be a directory!");
		}
		
		var outDir:String = inDir + '_converted';
		
		inDir = Path.addTrailingSlash(inDir);
		outDir = Path.addTrailingSlash(outDir);
		
		var files:Array<String> = FileSystem.readDirectory(inDir);
		
		for (file in files)
		{
			if (file.substr( -5, 5) == ".dds_")
			{
				convert(Path.join([inDir, file]), outDir);
			}
		}
		
		End.terminate(0, "Done");
	}
	
	private function convert(path:String, outDir:String)
	{
		var inBytes:BytesInput = new BytesInput(File.getBytes(path));
		inBytes.bigEndian = true;
		var outBytes:BytesOutput = new BytesOutput();
		outBytes.bigEndian = false;
		
		outBytes.writeInt32(inBytes.readInt32());
		
		var len:Int = inBytes.readInt32();
		inBytes.position -= 4;
		
		for (i in 0...Std.int(len / 4))
		{
			outBytes.writeInt32(inBytes.readInt32());
		}
		
		outBytes.bigEndian = true;
		
		var dat:Bytes = inBytes.read(inBytes.length - inBytes.position);
		outBytes.write(dat);
		
		FileSystem.createDirectory(outDir);
		var fname:String = Path.withoutExtension(Path.withoutDirectory(path));
		
		File.write(Path.join([outDir, fname + '.dds'])).write(outBytes.getBytes());
	}
	
	static function main() 
	{
		new Main();
	}
}