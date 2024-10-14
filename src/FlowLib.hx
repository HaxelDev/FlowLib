package;

import sys.FileSystem;
import sys.io.File;
import haxe.Http;
import haxe.Json;
import logs.*;

class FlowLib {
    public static var flowLibPath = "C:/FlowLib";
    public static var configFile = flowLibPath + "/flowlib.json";

    static function init() {
        if (!FileSystem.exists(flowLibPath)) {
            FileSystem.createDirectory(flowLibPath);
            Logger.log("Created FlowLib directory: " + flowLibPath);
        }
        if (!FileSystem.exists(configFile)) {
            var initialConfig = {
                libraries: []
            };
            var jsonData = Json.stringify(initialConfig, null, "  ");
            File.saveContent(configFile, jsonData);
            Logger.log("Created FlowLib config file: " + configFile);
        }
    }

    static function install(library:String, url:String, version:String = "latest") {
        init();
        
        var config = getConfig();
        for (lib in (cast config.libraries:Array<Dynamic>)) {
            if (lib.name == library && lib.version == version) {
                Logger.log('Library "$library" version "$version" is already installed.');
                return;
            }
        }

        var http = new Http(url);
        http.onData = function(data:String) {
            Logger.log('Library "$library" version "$version" installed successfully from "$url".');
            config.libraries.push({ name: library, version: version });
            saveConfig(config);
        };
    
        http.onError = function(error:String) {
            Logger.log('Failed to download library from "$url": $error');
        };
    
        http.request();
    }

    static function listLibraries() {
        init();
        var config = getConfig();
        if (config.libraries.length == 0) {
            Logger.log("No libraries installed.");
        } else {
            Logger.log("Installed libraries:");
            for (lib in (cast config.libraries:Array<Dynamic>)) {
                Logger.log("- " + lib.name + " (version: " + lib.version + ")");
            }
        }
    }

    static function remove(library:String, version:String = null) {
        init();
        
        var config = getConfig();
        var found = false;

        for (i in 0...config.libraries.length) {
            var lib = config.libraries[i];
            if (lib.name == library && (version == null || lib.version == version)) {
                found = true;
                var libraryPath = flowLibPath + "/" + library + "/" + lib.version;
                if (FileSystem.exists(libraryPath)) {
                    FileSystem.deleteDirectory(libraryPath);
                }

                config.libraries.splice(i, 1);
                saveConfig(config);

                Logger.log('Library "$library" version "${lib.version}" removed successfully.');
                break;
            }
        }

        if (!found) {
            Logger.log('Library "$library" with version "${version != null ? version : "any"}" is not installed.');
        }
    }

    static function update(library:String, url:String, version:String = "latest") {
        init();

        var config = getConfig();
        var libraryExists = false;

        for (lib in (cast config.libraries:Array<Dynamic>)) {
            if (lib.name == library) {
                libraryExists = true;
                break;
            }
        }

        if (!libraryExists) {
            Logger.log('Library "$library" is not installed. Use "install" command first.');
            return;
        }

        var http = new Http(url);
        http.onData = function(data:String) {
            for (lib in (cast config.libraries:Array<Dynamic>)) {
                if (lib.name == library) {
                    lib.version = version;
                    Logger.log('Library "$library" updated to version "$version" successfully from "$url".');
                    break;
                }
            }
            saveConfig(config);
        };

        http.onError = function(error:String) {
            Logger.log('Failed to download library from "$url": $error');
        };

        http.request();
    }    

    static function getConfig():Dynamic {
        var jsonData = File.getContent(configFile);
        return Json.parse(jsonData);
    }

    static function saveConfig(config:Dynamic) {
        var jsonData = Json.stringify(config, null, "  ");
        File.saveContent(configFile, jsonData);
    }

    static function main() {
        var args = Sys.args();
        if (args.length == 0) {
            printHelp();
            return;
        }

        var command = args[0];
        var param = args.length > 1 ? args[1] : null;
        var url = args.length > 2 ? args[2] : null;
        var version = args.length > 3 ? args[3] : "latest";

        switch (command) {
            case "install":
                if (param != null && url != null) {
                    install(param, url, version);
                } else {
                    Logger.log("Please specify a library and URL to install.");
                }
            case "list":
                listLibraries();
            case "remove":
                if (param != null) {
                    remove(param, version);
                } else {
                    Logger.log("Please specify a library to remove.");
                }
            case "update":
                if (param != null && url != null) {
                    update(param, url, version);
                } else {
                    Logger.log("Please specify a library and URL to update.");
                }
            default:
                printHelp();
        }
    }

    static function printHelp() {
        Logger.log('FlowLib Package Manager');
        Logger.log('-----------------------');
        Logger.log('Usage: flowlib install [library] [url] [version]');
        Logger.log('       flowlib list');
        Logger.log('       flowlib remove [library] [version]');
        Logger.log('       flowlib update [library] [url] [version]');
    }
}
