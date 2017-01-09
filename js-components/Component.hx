package ;

import js.html.*;
import js.Browser.*;
import uhx.uid.Hashids;
import haxe.Constraints.Function;

using haxe.io.Path;

class Component extends Element {
	
	//public static var KnownComponents:Storage = window.sessionStorage;
	//public static var ComponentStorage:Storage = window.sessionStorage;
	
	public static var KnownComponents(get, set):Array<String>;
	
	private static function get_KnownComponents():Array<String> {
		return if (window.sessionStorage.getItem('component_storage') == null) {
			[];
			
		} else {
			(haxe.Unserializer.run( window.sessionStorage.getItem('component_storage') ):Array<String>);
			
		}
		
	}
	
	private static function set_KnownComponents(v:Array<String>):Array<String> {
		window.sessionStorage.setItem('component_storage', haxe.Serializer.run(v));
		return v;
	}
	
	public static function main() {
		new Component();
	}
	
	private var total:Int = 0;
	private var pending:Int = 0;
	private var uid:String = '';
	private var root:ShadowRoot;
	private var local:HTMLDocument;
	private var htmlName:String = '';
	private var self:Component = null;
	private var htmlPrefix:String = 'hx';
	private var template:TemplateElement;
	private var hash:Hashids = new Hashids();
	private var observer:MutationObserver;
	private var timeoutId:Null<Int> = null;
	
	@:isVar private var eventMap(get, null):Map<String, Function>;
	
	public function new() {
		local = window.document.currentScript.ownerDocument;
		template = cast local.querySelector('template');
		
		switch ([template.hasAttribute('data-prefix'), template.hasAttribute('data-name')]) {
			case [x, true]:
				if (x) htmlPrefix = template.getAttribute('data-prefix');
				htmlName = '$htmlPrefix-' + template.getAttribute('data-name');
				//trace( 'registering element <$htmlName>' );
				if (KnownComponents.length == 0) {
					KnownComponents = [htmlName.toLowerCase()];
					
				} else {
					var kc = KnownComponents;
					if (kc.indexOf( htmlName.toLowerCase() ) == -1) {
						kc.push( htmlName.toLowerCase() );
						KnownComponents = kc;
						
					}
					
				}
				
				if (self == null) self = this;
				register();
				
			case _:
				
		}
		
	}
	
	private function get_eventMap():Map<String, Function> {
		if (eventMap == null) eventMap = ['DOMCustomElementAdded' => childAdded.bind(_), 'DOMCustomElementFinished' => check.bind(_)];
		return eventMap;
	}
	
	private function register():Void {
		if (self != null) window.document.registerElement('$htmlName', {prototype:self});
	}
	
	private function stampUid(node:Node):String {
		var result = '';
		
		if (node.nodeType == Node.TEXT_NODE) {
			result = node.textContent;
			
		} else if (node.nodeType != Node.COMMENT_NODE) {
			var ele:Element = untyped node;
			var stamp = ele.nodeName + [for (a in ele.attributes) if (a.name != 'uid') a.name + a.value].join('') + ele.querySelectorAll('*').length;
			//trace( stamp );
			result = hash.encode( [for (i in 0...stamp.length) stamp.charCodeAt(i)] );
			
		}
		
		return result;
	}
	
	public function createdCallback():Void {
		this.setAttribute('uid', uid = stampUid( this ) );
		var node = template.content;
		
		root = this.createShadowRoot();
		root.appendChild( window.document.importNode( node, true ) );
		
		observer = new MutationObserver(mutation);
		observer.observe(root, {childList:true, subtree:true});
		//trace( '$htmlName cb called' );
		
	}
	
	private function stampContents():Void {
		var contents = root.querySelectorAll('content');
		for (i in 0...contents.length) {
			var content:ContentElement = untyped contents[i];
			content.setAttribute('uid', '$uid.$i' );
			//trace( content );
		}
		
	}
	
	private function registerEvents():Void {
		for (key in eventMap.keys()) this.addEventListener(key, eventMap.get( key ));
	}
	
	public function attachedCallback():Void {
		stampContents();
		
		var customElements = this.querySelectorAll( KnownComponents.join(', ') );
		
		console.log( htmlName, customElements, customElements.length, this.childNodes, total, pending, KnownComponents, this.querySelectorAll( KnownComponents.join(', ') ) );
		
		//pending = total = customElements.length;
		
		//this.dispatchEvent( new CustomEvent('DOMCustomElementAdded', {detail:htmlName + [for (a in this.attributes) '[${a.name}="${a.value}"]'].join(''), bubbles:true, cancelable:true}) );
		this.dispatchEvent( new CustomEvent('DOMCustomElementAdded', {detail:uid, bubbles:true, cancelable:true}) );
		
		if (customElements.length > 0) {
			//trace(pending);
			registerEvents();
			
		} else {
			timeoutId = window.setTimeout( process, 0 );
			
		}
		
	}
	
	private function check(?e:CustomEvent):Void {
		//trace( 'checking $htmlName $pending - $uid' );
		if (e != null) {
			e.stopPropagation();
			--pending;
			console.log( htmlName, total, pending, e.detail );
			
		}
		
		console.log( '$htmlName $pending', uid );
		if (pending == 0) {
			if (timeoutId != null) {
				window.clearTimeout( timeoutId );
				
			}
			
			timeoutId = cast window.setTimeout( process, 0 );
			
		}
		
	}
	
	private function childAdded(?e:CustomEvent):Void {
		if (e != null && e.detail != uid) {
			e.stopPropagation();
			++pending;
			++total;
			console.log( htmlName, 'child added', uid, e.detail, total, pending );
			
		}
		
	}
	
	private function removeEvents():Void {
		for (key in eventMap.keys()) this.removeEventListener(key, eventMap.get( key ));
	}
	
	public function detachedCallback():Void {
		removeEvents();
	}
	
	private function done():Void {
		removeEvents();
		observer.disconnect();
		//trace( 'dispatching DOMCustomElementFinished from $htmlName - $uid' );
		this.dispatchEvent( new CustomEvent('DOMCustomElementFinished', {detail:uid, bubbles:true, cancelable:true}) );
		
	}
	
	private function processComponent():Void {
		console.log( 'lollol', this, this.parentElement, this.parentNode );
		var parent:Element = cast this.parentElement == null ? this.parentNode : this.parentElement;
		var shadowChildren = root.children;
		
		if (parent != null) {
			for (child in shadowChildren) {
				console.log( parent.nodeName + ' > ' + child.nodeName + [for (a in child.attributes) '[${a.name}="${a.value}"]'].join(''), parent.querySelectorAll(parent.nodeName + ' > ' + child.nodeName + [for (a in child.attributes) '[${a.name}="${a.value}"]'].join('')).length );
				if (parent.querySelectorAll(parent.nodeName + ' > ' + child.nodeName + [for (a in child.attributes) '[${a.name}="${a.value}"]'].join('')).length == 0) {
					parent.insertBefore(local.importNode(child, true), this);
					
				}
				
			}
			
			var shadowPoints = root.querySelectorAll('content');
			
			for (point in shadowPoints) {
				var point:ContentElement = untyped point;
				var cuid = untyped point.getAttribute('uid');
				var distributedNodes = point.getDistributedNodes();
				var placeholder = window.document.querySelectorAll('[uid="$cuid"]')[0];
				//trace( placeholder );
				if (placeholder != null) for (node in distributedNodes) {
					placeholder.parentElement.insertBefore(window.document.importNode(node, true), placeholder);
					
				}
				
			}
			
		} else {
			finish();
			
		}
		
	}
	
	private function process():Void {
		console.log( htmlName, total, pending, this.childNodes );
		if (pending == 0) {
			console.log( 'process component', htmlName, uid, total, pending );
			processComponent();
			
			console.log( 'process completed', htmlName, uid, total, pending );
			finish();
			
		}
		
	}
	
	private function finish():Void {
		done();
		pending = total = -1;
		removeSelf();
	}
	
	private function removeSelf():Void {
		/*var contents = root.querySelectorAll('content[uid]');
		console.log( 'content elements', contents );
		if (contents.length > 0) for (content in contents) {
			var matches = window.document.querySelectorAll('[uid]');
			console.log( matches );
			
		}*/
		var self = window.document.querySelector( '[uid="$uid"]' );
		if (self != null) self.parentNode.removeChild( self );
	}
	
	private function mutation(changes:Array<MutationRecord>, observer:MutationObserver):Void {
		console.log( 'MUTATION', [for (c in changes) c.type] );
		//console.log( window.document.importNode( this, true ) );
		for (change in changes) switch change.type {
			case 'attributes':
				
			case 'characterData':
				
			case 'childList':
				console.log( 'CHILD LIST MUTATED for $uid', change );
				// The node whose child list changed.
				var parent = change.target;
				
				// I'm only _currently_ interested in added nodes.
				var newChildren = [for (n in change.addedNodes) n];
				
				/*var components = newChildren.filter( function(n) return KnownComponents.getItem(n.nodeName.toLowerCase()) != null );
				
				if (components.length > 0) {
					//console.log( 'increasing counters', total, pending, parent, components );
					total += components.length;
					pending += components.length;
					
				}*/
				
			case _:
				
		}
	}
	
}
