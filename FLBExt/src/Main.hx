package ;

import console.End;
import format.png.Data;
import format.png.Writer;
import haxe.io.Output;
import haxe.io.Path;
import neko.Lib;
import console.Begin;
import sys.FileSystem;
import sys.io.File;
import systools.Dialogs;
import systools.Dialogs.FILEFILTERS;

class Main 
{
	static private inline var USAGE:String = "Command line usage: FLBExt inFile outDir\n    inDir: Directory containing the files to extract\n    outDir: Directory where extracted images will be saved";
	static private var outDirExists:Bool = true;
	
	static function main() 
	{
		Begin.init();
		Begin.usage = USAGE;
		Begin.functions[0] = selectFiles;
		Begin.functions[2] = getPathsFromArgs;
		Begin.parseArgs();
	}
	
	static private function selectFiles(args:Array<String>)
	{
		Sys.println("Select the FLB files to extract images from");
		
		var filter:FILEFILTERS = { count:1, descriptions:["FLB Files"], extensions:["*.flb"] };
		var files:Array<String> = Dialogs.openFile("Choose files", "Choose files", filter);
		
		if (files == null)
		{
			End.anyKeyExit(2, "No files selected!");
		}
		
		Sys.println("Select the folder to save the extracted images");
		
		var outDir:String = Dialogs.folder("Choose folder", "Choose folder");
		
		if (outDir == null)
		{
			End.anyKeyExit(2, "No folder selected!");
		}
		
		extractImages(files, outDir);
	}
	
	static private function getPathsFromArgs(args:Array<String>)
	{
		if (FileSystem.exists(args[0]))
		{
			if (!FileSystem.isDirectory(args[0]))
			{
				End.anyKeyExit(3, "First argument is not a directory!");
			}
		}
		else
		{
			End.anyKeyExit(3, "First argument does not exist!");
		}
		
		var inFiles:Array<String> = FileSystem.readDirectory(args[0]);
		var filesToRemove:Array<String> = new Array<String>();
		
		for (i in 0...inFiles.length)
		{
			if (new Path(inFiles[i]).ext != "flb")
			{
				filesToRemove.push(inFiles[i]);
			}
			else
			{
				inFiles[i] = FileSystem.fullPath(args[0]) + "/" + inFiles[i];
			}
		}
		
		for (file in filesToRemove)
		{
			inFiles.remove(file);
		}
		
		if (FileSystem.exists(args[1]))
		{
			if (!FileSystem.isDirectory(args[1]))
			{
				End.anyKeyExit(3, "Second argument is not a directory!");
			}
		}
		else
		{
			outDirExists = false;
		}
		
		extractImages(inFiles, args[1]);
	}
	
	static private function extractImages(inFiles:Array<String>, outDir:String)
	{
		for (file in inFiles)
		{
			var filePath:Path = new Path(file);
			var fileName:String = filePath.file + "." + filePath.ext;
			
			var flb:FLB = new FLB(File.getBytes(file));
			Sys.println("Extracting " + fileName);
			var images:Array<Data> = flb.getImages();
			
			if (images.length < 1)
			{
				Sys.println("No images");
				continue;
			}
			
			if (!outDirExists)
			{
				FileSystem.createDirectory(outDir);
			}
			
			var finalDir:String = outDir + "/" + filePath.file + "_extracted";
			
			FileSystem.createDirectory(finalDir);
			
			for (i in 0...images.length)
			{
				var out:Output = File.write(finalDir + "/" + filePath.file + "_" + i + ".png");
				var w:Writer = new Writer(out);
				w.write(images[i]);
			}
			
			Sys.println("Done");
		}
		
		Sys.println("Complete");
	}
}