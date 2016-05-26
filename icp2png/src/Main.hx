package ;

import easyconsole.Begin;
import easyconsole.End;
import format.png.Data;
import format.png.Reader;
import format.png.Tools;
import format.png.Writer;
import haxe.ds.Vector;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.io.Output;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;
import sys.io.FileSeek;

class Main 
{
	private var f:FileInput;
	private var outDir:String;
	private var toIcp:Bool = false;
	
	private function new() 
	{
		Begin.init();
		Begin.usage = "Usage: icp2png inFile outDir -p\n    inFile: The file to convert. Can alternatively be a folder containing the files to convert\n    outDir: The folder to save the converted files to. If the -p flag is included, this folder must exist and contain a corresponding .icp file for each .png you are converting\n    [-p]: Optional flag, include to convert from .png to .icp";
		Begin.functions = [null, null, checkArgs];
		Begin.parseArgs();
	}
	
	private function checkArgs()
	{
		if (Begin.args[2] == "-p") toIcp = true;
		
		if (!FileSystem.exists(Begin.args[0]))
		{
			End.terminate(1, "inFile must exist!");
		}
		
		outDir = Begin.args[1];
		
		if (toIcp && !FileSystem.exists(outDir))
		{
			End.terminate(2, "outDir must exist!");
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
				if (Path.extension(file).toLowerCase() == "icp")
				{
					convertICP(Begin.args[0] + "/" + file);
				}
				else
				if (Path.extension(file).toLowerCase() == "png")
				{
					convertPNG(Begin.args[0] + "/" + file);
				}
			}
		}
		else
		{
			var file:String = Begin.args[0];
			
			if (Path.extension(file).toLowerCase() == "icp")
			{
				convertICP(file);
			}
			else
			if (Path.extension(file).toLowerCase() == "png")
			{
				convertPNG(file);
			}
		}
		
		End.terminate(0, "Done");
	}
	
	/**
	 * Convert from .icp to .png
	 */
	private function convertICP(path:String)
	{
		Sys.println("Converting " + path);
		f = File.read(path);
		f.bigEndian = false;
		
		//Checking validity
		if (f.readString(3) != "ICP")
		{
			Sys.println("Invalid ICP header!");
			f.close();
			return;
		}
		
		//Read header
		f.seek(8, FileSeek.SeekBegin);
		var w:Int = f.readInt16();
		var h:Int = f.readInt16();
		
		//Extract the PNG
		f.seek(0, FileSeek.SeekEnd);
		var pngLength:Int = f.tell() - 0x0C;
		f.seek(0x0C, FileSeek.SeekBegin);
		var bi:BytesInput = new BytesInput(f.read(pngLength));
		var inDat:Data = new Reader(bi).read();
		f.close();
		bi.close();
		
		//Get the data from the PNG pixels
		var inPixels:Bytes = Tools.extract32(inDat);
		var cleanRawO:BytesOutput = new BytesOutput();
		
		trace(StringTools.hex(inPixels.getInt32(0), 8));
		trace(StringTools.hex(inPixels.get(4), 2));
		
		for (i in 5...inPixels.length)
		{
			if (i % 4 != 3 && i > 4)
			{
				cleanRawO.writeByte(inPixels.get(i));
			}
		}
		
		var cleanRawI:BytesInput = new BytesInput(cleanRawO.getBytes());
		cleanRawO.close();
		cleanRawI.bigEndian = true;
		
		//Get the palette
		var palette:Array<Int> = new Array<Int>();
		
		while (cleanRawI.position < 0x400)
		{
			var rgba:Int = cleanRawI.readInt32();
			var argb:Int = ((rgba & 0xFFFFFF00) >> 8) + ((rgba & 0xFF) << 24);
			palette.push(argb);
		}
		
		//Read the actual pixels
		var finalOut:BytesOutput = new BytesOutput();
		finalOut.bigEndian = true;
		
		while (cleanRawI.position < cleanRawI.length)
		{
			finalOut.writeInt32(palette[cleanRawI.readByte()]);
		}
		
		//Turn it into a PNG and save
		FileSystem.createDirectory(outDir);
		
		var filename:String = new Path(path).file;
		
		if (new Path(filename).ext != "png")
		{
			filename += ".png";
		}
		
		var outDat:Data = Tools.build32ARGB(w, h, finalOut.getBytes());
		var w:Writer = new Writer(File.write(outDir + "/" + filename));
		
		Sys.println("Saving " + outDir + "/" + filename);
		w.write(outDat);
	}
	
	/**
	 * Convert from .png to .icp
	 */
	private function convertPNG(path:String)
	{
		Sys.println("Converting " + path);
		f = File.read(path);
		f.bigEndian = false;
		
		var inPng:Data;
		
		//Checking validity
		try
		{
			inPng = new Reader(f).read();
		}
		catch (e:Dynamic)
		{
			Sys.println("Invalid PNG file!");
			f.close();
			return;
		}
		
		var w:Int = Tools.getHeader(inPng).width;
		var h:Int = Tools.getHeader(inPng).height;
		
		var icps:Array<String> = FileSystem.readDirectory(outDir);
		var inName:String = new Path(path).file.split(".")[0];
		var outName:String = null;
		
		for (icp in icps)
		{
			if (Path.extension(icp).toLowerCase() == "icp" && icp.split(".")[0] == inName)
			{
				outName = icp;
				break;
			}
		}
		
		if (outName == null)
		{
			Sys.println("outdir does not contain corresponding .icp!");
			f.close();
			return;
		}
		
		var inPixelsB:Bytes = Tools.extract32(inPng);
		Tools.reverseBytes(inPixelsB);
		var inPixels:BytesInput = new BytesInput(inPixelsB);
		//var paletteMap:Map<String, Int> = new Map<String, Int>();
		var palette:Array<Int> = new Array<Int>();
		var outPixels:BytesOutput = new BytesOutput();
		
		while (inPixels.position < inPixels.length)
		{
			var c:Int = inPixels.readInt32();
			
			var index:Int = palette.indexOf(c);
			
			if (index < 0) palette.push(c);
			else outPixels.writeByte(index);
			//paletteMap.set('c' + StringTools.hex(c, 8), c);
		}
		
		//var palette:Array<Int> = [for (v in paletteMap.iterator()) v];
		
		var outPal:BytesOutput = new BytesOutput();
		
		for (i in 0...palette.length)
		{
			var argb:Int = palette[i];
			var rgba:Int = ((argb & 0xFFFFFF) << 8) + ((argb & 0xFF000000) >> 24);
			
			outPal.writeInt32(rgba);
		}
		
		var finalOut:BytesOutput = new BytesOutput();
		var palBytes:Bytes = outPal.getBytes();
		finalOut.writeInt32(0xFF020100);
		finalOut.writeByte(0x03);
		finalOut.bigEndian = true;
		
		for (i in 0...palBytes.length)
		{
			finalOut.writeByte(palBytes.get(i));
			if (i % 3 == 2) finalOut.writeByte(0xFF);
		}
		
		var pixBytes:Bytes = outPixels.getBytes();
		
		for (i in 0...pixBytes.length)
		{
			finalOut.writeByte(pixBytes.get(i));
			if (i % 3 == 2) finalOut.writeByte(0xFF);
		}
		
		//finalOut.writeFullBytes(outPal.getBytes(), 0, outPal.length);
		//finalOut.writeFullBytes(outPixels.getBytes(), outPal.length, outPixels.length);
		
		var outDat:Data = Tools.build32ARGB(w, h, finalOut.getBytes());
		var pngOut:BytesOutput = new BytesOutput();
		var w:Writer = new Writer(pngOut);
		
		w.write(outDat);
		
		var fIn:FileInput = File.read(outDir + "/" + outName);
		var icpHead:Bytes = Bytes.alloc(0x0C);
		fIn.readBytes(icpHead, 0, 0x0C);
		fIn.close();
		var fOut:FileOutput = File.write(outDir + "/" + outName);
		fOut.flush();
		Sys.println("Saving " + outDir + "/" + outName);
	}
	
	static function main()
	{
		new Main();
	}
}