package funkin.backend.system.macros;

#if macro
import haxe.macro.*;
import haxe.macro.Expr;

/**
 * Macros containing additional help functions to expand HScript capabilities.
 */
class Macros {
	public static function addAdditionalClasses() {
		for(inc in [
			// FLIXEL
			"flixel.util", "flixel.ui", "flixel.tweens", "flixel.tile", "flixel.text",
			"flixel.system", "flixel.sound", "flixel.path", "flixel.math", "flixel.input",
			"flixel.group", "flixel.graphics", "flixel.effects", "flixel.animation",
			// FLIXEL ADDONS
			"flixel.addons.api", "flixel.addons.display", "flixel.addons.effects", "flixel.addons.ui",
			"flixel.addons.plugin", "flixel.addons.text", "flixel.addons.tile", "flixel.addons.transition",
			"flixel.addons.util",
			// OTHER LIBRARIES & STUFF
			#if THREE_D_SUPPORT "away3d", "flx3d", #end
			#if VIDEO_CUTSCENES "hxvlc.flixel", "hxvlc.openfl", #end
			#if NAPE_ENABLED "nape", "flixel.addons.nape", #end
			// BASE HAXE
			"DateTools", "EReg", "Lambda", "StringBuf", "haxe.crypto", "haxe.display", "haxe.exceptions", "haxe.extern", "scripting", "animate"
		])
			Compiler.include(inc);

		var isHl = Context.defined("hl");

		var compathx4 = [
			"sys.db.Sqlite",
			"sys.db.Mysql",
			"sys.db.Connection",
			"sys.db.ResultSet",
			"haxe.remoting.Proxy",
		];

		if(Context.defined("sys")) {
			for(inc in ["sys", "openfl.net", "funkin.backend.system.net"]) {
				if(!isHl) Compiler.include(inc, compathx4);
				else {

					// TODO: Hashlink
					//Compiler.include(inc, compathx4.concat(["sys.net.UdpSocket", "openfl.net.DatagramSocket"]); // fixes FATAL ERROR : Failed to load function std@socket_set_broadcast
				}
			}
		}

		Compiler.include("funkin", [#if !UPDATE_CHECKING 'funkin.backend.system.updating' #end]);
	}

	public static function initMacros() {
		if (Context.defined("hl")) {
			for (c in ["lime", "std", "Math", ""]) Compiler.addGlobalMetadata(c, "@:build(funkin.backend.system.macros.HashLinkFixer.build())");
		}

		final macroPath = 'funkin.backend.system.macros.Macros';
		Compiler.addMetadata('@:build($macroPath.buildLimeAssetLibrary())', 'lime.utils.AssetLibrary');
		#if (flixel < "5.4.0")
		Compiler.addMetadata('@:build($macroPath.buildFlxAtlasFrames())', 'flixel.graphics.frames.FlxAtlasFrames');
		Compiler.addMetadata('@:build($macroPath.buildFlxAnimateFrames())', 'animate.FlxAnimateFrames');
		#end

		//Adds Compat for #if hscript blocks when you have hscript improved
		if (Context.defined("hscript_improved") && !Context.defined("hscript")) {
			Compiler.define('hscript');
		}
	}

	public static function buildLimeAssetLibrary():Array<Field> {
		final fields:Array<Field> = Context.getBuildFields(), pos:Position = Context.currentPos();

		fields.push({name: 'tag', access: [APublic], pos: pos, kind: FVar(macro :funkin.backend.assets.AssetSource)});
		fields.push({name: 'isCompressed', access: [APublic], pos: pos, kind: FVar(macro :Bool, macro false)});

		return fields;
	}

	/*
	
	cne flixel uses 5.3, the version that VERY CONVENIENTLY does not have .addAtlas
	(it would make my life easier....)

	!!!!!!! REMOVE ALL THIS WHEN CNE FLIXEL IS UPDATED !!!!!!!!!!!!!!!!! it wont be necessary anymore
	or it could be added to the existing build. idk

	*/
	#if (flixel < "5.4.0")
	public static function buildFlxAtlasFrames():Array<Field> {
		final fields:Array<Field> = Context.getBuildFields(), pos:Position = Context.currentPos();
		for (f in fields) {
			switch (f.name) {
				case 'usedGraphics' | 'addAtlas' | 'destroy':
					fields.remove(f);
			}
		}

		fields.push({name: 'usedGraphics', access: [], pos: pos, kind: FVar(macro :Array<FlxGraphic>, macro [])});
		fields.push({name: "destroy", access: [AOverride], pos: pos, kind: FFun({ret: macro :Void, args: [], expr: macro {
			while (usedGraphics.length > 0)
				--usedGraphics.shift().useCount;
		
			super.destroy();
		}})});
		fields.push({name: "addAtlas", access: [APublic], pos: pos, kind: FFun({
			ret: macro :FlxAtlasFrames, args: [
				{name: "collection", type: macro :FlxAtlasFrames}
			], expr: macro {
				for (frame in collection.frames)
					pushFrame(frame);
				
				if (!usedGraphics.contains(collection.parent))
				{
					usedGraphics.push(collection.parent);
					++collection.parent.useCount;
				}
				
				return this;
			}
		})});
		return fields;
	}
	public static function buildFlxAnimateFrames():Array<Field> {
		final fields:Array<Field> = Context.getBuildFields(), pos:Position = Context.currentPos();
		for (f in fields) {
			switch (f.name) {
				case 'addAtlas':
					fields.remove(f);
			}
		}

		fields.push({name: "addAtlas", access: [APublic, AOverride], pos: pos, kind: FFun({
			ret: macro :FlxAtlasFrames, args: [
				{name: "collection", type: macro :FlxAtlasFrames}
			], expr: macro {
				if (collection is FlxAnimateFrames)
				{
					// Add the texture atlas collection
					var animateCollection:FlxAnimateFrames = cast collection;
					addedCollections.push(animateCollection);

					// Add other non-texture atlas frames that could've been added to the animate frames, such as Sparrow

					var spritemap:FlxAnimateSpritemapCollection = cast animateCollection.parent;
					for (graphic in animateCollection.usedGraphics)
					{
						if (!spritemap.spritemaps.contains(graphic)) // Graphic isnt part of the texture atlas spritemap, check for atlas frames
						{
							var atlasFrames = FlxAtlasFrames.findFrame(graphic);
							if (atlasFrames != null)
								super.addAtlas(atlasFrames);
						}
					}

					return this;
				}

				return super.addAtlas(collection);
			}
		})});

		// TODO: implement overload
		fields.push({name: "combineAtlas", access: [APublic, AStatic], pos: pos, kind: FFun({
			ret: macro :FlxAtlasFrames, args: [
				{name: "atlasA", type: macro :FlxAtlasFrames},
				{name: "atlasB", type: macro :FlxAtlasFrames}
			], expr: macro {
				if (atlasA is FlxAnimateFrames)
					return atlasA.addAtlas(atlasB);

				return atlasB.addAtlas(atlasA);
			}
		})});
		return fields;
	}
	#end
}
#end