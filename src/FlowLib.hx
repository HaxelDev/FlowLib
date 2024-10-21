package;

import sys.FileSystem;
import sys.io.File;
import haxe.Json;
import logs.*;

using StringTools;

class FlowLib {
    public static var flowLibPath = getPlatformSpecificPath();
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

        if (!isGitAvailable()) {
            Logger.log('Git is not installed. Please install Git to use this feature.');
            return;
        }
    
        var libraryPath = flowLibPath + "/" + library + "/" + version;
        if (!FileSystem.exists(libraryPath)) {
            FileSystem.createDirectory(libraryPath);
        }
    
        var cloneCmd = getGitCommand('clone', url.replace("\\", "/"), libraryPath);
        Logger.log("Executing command: " + cloneCmd);
    
        var result = Sys.command(cloneCmd);
        if (result == 0) {
            Logger.log('Library "$library" version "$version" installed successfully from "$url".');
            config.libraries.push({ name: library, version: version });
            saveConfig(config);
        } else {
            Logger.log('Failed to install library "$library". Command returned: ' + result);
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

        if (!isGitAvailable()) {
            Logger.log('Git is not installed. Please install Git to use this feature.');
            return;
        }

        var libraryPath = flowLibPath + "/" + library + "/" + version;
        if (FileSystem.exists(libraryPath)) {
            var pullCmd = getGitCommand('pull', null, libraryPath);
            Sys.command(pullCmd, []);
            Logger.log('Library "$library" updated to version "$version" successfully.');
        } else {
            Logger.log('Library path does not exist. Please reinstall the library.');
        }
    }

    static function getGitCommand(command:String, url:String, libraryPath:String):String {
        var platform = Sys.systemName().toLowerCase();
        var cmd:String = '';
    
        switch (platform) {
            case "windows":
                if (command == "clone") {
                    cmd = 'cmd /c git clone ' + url.replace("\\", "/") + ' "' + libraryPath + '"';
                } else if (command == "pull") {
                    cmd = 'cmd /c cd "' + libraryPath + '" && git pull';
                }
            default:
                if (command == "clone") {
                    cmd = 'git clone ' + url.replace("\\", "/") + ' ' + libraryPath;
                } else if (command == "pull") {
                    cmd = 'git -C ' + libraryPath + ' pull';
                }
        }
        return cmd;
    }

    static function getPlatformSpecificPath():String {
        var platform = Sys.systemName().toLowerCase();
        switch (platform) {
            case "windows":
                return "C:/FlowLib";
            case "linux":
                return "/usr/local/FlowLib";
            case "macos":
                return "/usr/local/FlowLib";
            default:
                throw "Unsupported platform: " + platform;
        }
    }

    static function isGitAvailable():Bool {
        var platform = Sys.systemName().toLowerCase();
        var cmd:String;
        
        if (platform == "windows") {
            cmd = "where git";
        } else {
            cmd = "which git";
        }
    
        try {
            var gitCheckCmd = Sys.command(cmd);
            return gitCheckCmd == 0;
        } catch (e:Dynamic) {
            Logger.log('Git is not installed or not found in PATH: ' + e);
            return false;
        }
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
