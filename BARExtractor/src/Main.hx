package ;

import flash.display.Sprite;
import flash.events.Event;
import flash.Lib;
import format.png.Data;
import format.png.Writer;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.io.Path;
import haxe.Log;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;

/**
 * ...
 * @author Puggsoy
 */

class Main extends Sprite 
{
	var inited:Bool;
	
	/* ENTRY POINT */
	
	private var _inPath:Path;
	private var _outPath:Path;
	
	private var _bytesIn:BytesInput;
	private var _barFile:BARFile;
	
	function resize(e) 
	{
		if (!inited) init();
		// else (resize or orientation change)
	}
	
	function init() 
	{
		if (inited) return;
		inited = true;
		
		var args:Array<String> = Sys.args();
		
		if (args.length > 0)
		{
			_inPath = new Path(FileSystem.fullPath(args[0]));
			
			if (FileSystem.exists(_inPath.toString()) && !FileSystem.isDirectory(_inPath.toString()))
			{
				loadFile();
			}
			else
			{
				Log.trace(_inPath.toString() + " doesn't exist!");
				
				Sys.exit(1);
			}
		}
		else
		{
			Log.trace("No arguments passed! Drag a file onto the .exe, or run this in the command-line with the BAR file as the only argument.");
			
			Sys.exit(2);
		}
	}
	
	private function loadFile()
	{
		var file:FileInput = File.read(_inPath.toString());
		var bytes:Bytes = file.readAll();
		_bytesIn = new BytesInput(bytes);
		file.close();
		
		_barFile = new BARFile(_bytesIn, bytes.length, this);
	}
	
	public function saveFiles(images:Array<BARImage>)
	{
		_outPath = new Path(Path.addTrailingSlash(Path.addTrailingSlash(_inPath.dir) + _inPath.file + "_output"));
		FileSystem.createDirectory(_outPath.toString());
		
		for (i in 0...images.length)
		{
			var outData:Data = images[i].getData();
			var out:FileOutput = File.write(_outPath.toString() + "out_" + i + ".png");
			new Writer(out).write(outData);
			out.close();
		}
		
		Sys.exit(0);
	}

	/* SETUP */

	public function new() 
	{
		super();	
		addEventListener(Event.ADDED_TO_STAGE, added);
	}

	function added(e) 
	{
		removeEventListener(Event.ADDED_TO_STAGE, added);
		stage.addEventListener(Event.RESIZE, resize);
		#if ios
		haxe.Timer.delay(init, 100); // iOS 6
		#else
		init();
		#end
	}
	
	public static function main() 
	{
		// static entry point
		Lib.current.stage.align = flash.display.StageAlign.TOP_LEFT;
		Lib.current.stage.scaleMode = flash.display.StageScaleMode.NO_SCALE;
		Lib.current.addChild(new Main());
	}
}
