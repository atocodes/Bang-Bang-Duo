// voxide_web.js
// Loaded by the Godot Web export HTML shell via the plugin's export hook.
// Bridges GDScript calls to the official Voxide browser SDK (pinned @0.8.0).
//
// The Voxide browser SDK is loaded from:
//   https://unpkg.com/@voxide/react@0.8.0/dist/voxide.browser.js
//
// GDScript interacts with this file only through VoxideWebBridge (GDScript),
// which calls JavaScript.call() into the window._VoxideBridge namespace.

(function () {
  "use strict";

  // Guard against double-loading.
  if (window._VoxideBridge) return;

  // ---------------------------------------------------------------------------
  // Internal state
  // ---------------------------------------------------------------------------
  var _client = null;
  var _unsubscribe = null;
  var _initialized = false;
  var _godotCallback = null; // Set by GDScript via _VoxideBridge.setCallback().

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  function _emit(type, payload) {
    if (typeof _godotCallback === "function") {
      try {
        _godotCallback(JSON.stringify({ type: type, payload: payload || {} }));
      } catch (e) {
        console.error("[VoxideBridge] Callback error:", e);
      }
    }
  }

  function _loadSdkScript(cb) {
    if (typeof Voxide !== "undefined") {
      cb();
      return;
    }
    var s = document.createElement("script");
    s.src = "https://unpkg.com/@voxide/react@0.8.0/dist/voxide.browser.js";
    s.onload = cb;
    s.onerror = function () {
      _emit("error", { message: "Failed to load Voxide browser SDK." });
    };
    document.head.appendChild(s);
  }

  // ---------------------------------------------------------------------------
  // Public bridge API (called from GDScript via JavaScript.call())
  // ---------------------------------------------------------------------------
  window._VoxideBridge = {

    /**
     * Register a GDScript callback function.
     * The callback receives a single JSON string on every Voxide event.
     */
    setCallback: function (cb) {
      _godotCallback = cb;
    },

    /**
     * Initialize the Voxide client with the given public key.
     * Must be called before connect().
     */
    init: function (publicKey, baseUrl) {
      _loadSdkScript(function () {
        try {
          _client = new Voxide.VoxideClient({
            publicKey: publicKey,
            baseUrl: baseUrl || undefined,
          });

          _client.on("status", function (status) {
            _emit("status", { status: status });
          });

          _client.on("transcript", function (data) {
            _emit("transcript", data);
          });

          _client.on("message", function (data) {
            _emit("message", data);
          });

          _client.on("action", function (data) {
            _emit("action", data);
          });

          _client.on("error", function (msg) {
            _emit("error", { message: msg });
          });

          _client.on("ready", function (config) {
            _initialized = true;
            _emit("ready", { config: config });
          });

          _client.init().catch(function (err) {
            _emit("error", { message: err.message });
          });
        } catch (e) {
          _emit("error", { message: e.message });
        }
      });
    },

    /** Open a live voice session. */
    connect: function () {
      if (!_client) { _emit("error", { message: "Client not initialized." }); return; }
      _client.connect().catch(function (e) {
        _emit("error", { message: e.message });
      });
    },

    /** Close the live session. */
    disconnect: function () {
      if (!_client) return;
      _client.disconnect();
    },

    /** Send a text message to the AI. */
    sendText: function (text) {
      if (!_client) return;
      _client.sendText(text);
    },

    /** Interrupt the current AI speech. */
    interrupt: function () {
      if (!_client) return;
      _client.interrupt();
    },

    /**
     * Register a tool that the AI can call.
     * toolDef: { name, description, params, dangerous }
     * GDScript will receive tool_call events and must call sendToolResult().
     */
    registerTool: function (toolDef) {
      if (!_client) return;
      var entry = {};
      entry[toolDef.name] = {
        description: toolDef.description,
        params: toolDef.params || {},
        dangerous: toolDef.dangerous || false,
        handler: function (args) {
          // Signal GDScript to handle this tool call.
          // GDScript will call sendToolResult when ready.
          _emit("tool_call", { name: toolDef.name, args: args });
          // Return a pending promise resolved by sendToolResult.
          return new Promise(function (resolve) {
            window._VoxideBridge._pending = window._VoxideBridge._pending || {};
            window._VoxideBridge._pending[toolDef.name] = resolve;
          });
        },
      };
      _client.register(entry);
    },

    /**
     * Resolve a pending tool call from GDScript.
     * result: Dictionary serialized as JSON string.
     */
    sendToolResult: function (toolName, resultJson) {
      var pending = window._VoxideBridge._pending || {};
      if (pending[toolName]) {
        try {
          pending[toolName](JSON.parse(resultJson));
        } catch (e) {
          pending[toolName]({ status: "error", message: e.message });
        }
        delete pending[toolName];
      }
    },

    /**
     * Inject current game state.
     * stateJson: Dictionary serialized as JSON string.
     */
    setState: function (stateJson) {
      if (!_client) return;
      try {
        _client.setState(JSON.parse(stateJson));
      } catch (e) {
        console.error("[VoxideBridge] setState parse error:", e);
      }
    },

    /**
     * Set active route for scoped tools.
     */
    setActiveRoute: function (route) {
      if (!_client) return;
      _client.setActiveRoute(route);
    },

    /** Returns the current snapshot as JSON string. */
    getSnapshot: function () {
      if (!_client) return "{}";
      return JSON.stringify(_client.getSnapshot());
    },

    /** Returns current input level (0.0 - 1.0). */
    getInputLevel: function () {
      if (!_client) return 0;
      return _client.getInputLevel();
    },

    /** Returns current output level (0.0 - 1.0). */
    getOutputLevel: function () {
      if (!_client) return 0;
      return _client.getOutputLevel();
    },

    _pending: {},
  };
})();
