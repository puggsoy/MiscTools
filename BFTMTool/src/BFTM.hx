package ;
import format.tools.Deflate;
import format.tools.Inflate;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.io.Path;
import haxe.Log;
import haxe.zip.InflateImpl;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;

/**
 * ...
 * @author Puggsoy
 */
class BFTM
{
	public var entries:Array<Entry>;
	public var bytes:Bytes;
	
	public function new() 
	{
		
	}
	
	public function unpack(bftmPath:Path)
	{
		var f:FileInput = File.read(bftmPath.toString());
		bytes = f.readAll();
		var input:BytesInput = new BytesInput(bytes);
		input.bigEndian = true;
		
		var fileNum:UInt = input.readInt32();
		
		entries = new Array<Entry>();
		
		for (i in 0...fileNum)
		{
			var entry:Entry = new Entry();
			entry.nameLength = input.readInt32();
			entry.compressedName = Bytes.alloc(entry.nameLength);
			input.readBytes(entry.compressedName, 0, entry.nameLength);
			entry.name = decompressString(entry.compressedName);
			entry.offset = input.readInt32();
			entry.size = input.readInt32();
			
			entries.push(entry);
		}
	}
	
	public function pack(root:String)
	{
		try
		{
			if (!FileSystem.isDirectory(root))
			{
				throw "Must be a directory!";
			}
		}
		catch(e:Dynamic)
		{
			if (e == "Must be a directory!")
			{
				Sys.println(e);
			}
			else
			{
				Sys.println("Directory must exist!");
			}
			
			Sys.getChar(false);
			Sys.exit(2);
		}
		
		entries = new Array<Entry>();
		
		scanDirectories(root);
		
		var currOffset:Int = 4;
		
		for (entry in entries)
		{
			entry.name = entry.name.substr(root.length + 1);
			entry.compressedName = compressString(entry.name);
			entry.nameLength = entry.compressedName.length;
			
			currOffset += 12 + entry.nameLength;
		}
		
		for (entry in entries)
		{
			entry.offset = currOffset;
			currOffset += entry.size;
		}
		
		var byteWriter:BytesOutput = new BytesOutput();
		byteWriter.bigEndian = true;
		
		byteWriter.writeInt32(entries.length);
		
		for (entry in entries)
		{
			byteWriter.writeInt32(entry.nameLength);
			byteWriter.writeBytes(entry.compressedName, 0, entry.nameLength);
			byteWriter.writeInt32(entry.offset);
			byteWriter.writeInt32(entry.size);
		}
		
		for (entry in entries)
		{
			Sys.println("packing " + entry.name);
			
			var fileIn:FileInput = File.read(root + "/" + entry.name);
			var fileBytes:Bytes = fileIn.readAll();
			fileIn.close();
			
			if (new Path(entry.name).ext == "xml")
			{
				fileBytes = Deflate.run(fileBytes);
			}
			
			byteWriter.writeBytes(fileBytes, 0, fileBytes.length);
		}
		
		bytes = byteWriter.getBytes();
	}
	
	private function scanDirectories(dir:String)
	{
		var contents:Array<String> = FileSystem.readDirectory(dir);
		
		for (file in contents)
		{
			var filePath:Path = new Path(dir + "/" + file);
			
			if (FileSystem.isDirectory(filePath.toString()))
			{
				scanDirectories(filePath.toString());
			}
			else
			{
				var entry:Entry = new Entry();
				entry.name = filePath.toString();
				
				if (filePath.ext == "xml")
				{
					entry.size = Deflate.run(File.read(filePath.toString()).readAll()).length;
				}
				else
				{
					entry.size = FileSystem.stat(entry.name).size;
				}
				
				entries.push(entry);
			}
		}
	}
	
	private function decompressString(bytes:Bytes):String
	{
		var decompressed:Bytes = Inflate.run(bytes);
		return decompressed.toString();
	}
	
	private function compressString(string:String):Bytes
	{
		var converter:BytesOutput = new BytesOutput();
		converter.writeString(string);
		return Deflate.run(converter.getBytes());
	}
}