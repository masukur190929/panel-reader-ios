#!/usr/bin/env python3
"""Generate a normal Xcode project using only Python's standard library."""
from pathlib import Path
import hashlib
import json
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "PanelReader.xcodeproj"
objects = {}

def identifier(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()

def add(key_name, isa, **fields):
    key = identifier(key_name)
    objects[key] = {"isa": isa, **fields}
    return key

def encode(value, level=0):
    indent = "\t" * level
    if isinstance(value, dict):
        lines = ["{"]
        for key, item in value.items():
            lines.append("\t" * (level + 1) + json.dumps(str(key)) + " = " + encode(item, level + 1) + ";")
        lines.append(indent + "}")
        return "\n".join(lines)
    if isinstance(value, list):
        return "(\n" + "".join("\t" * (level + 1) + encode(item, level + 1) + ",\n" for item in value) + indent + ")"
    if isinstance(value, int):
        return str(value)
    return json.dumps(str(value), ensure_ascii=False)

def configurations(name, base, debug=None, release=None):
    variants = []
    for variant, extra in [("Debug", debug or {}), ("Release", release or {})]:
        variants.append(add(name + variant, "XCBuildConfiguration", name=variant, buildSettings={**base, **extra}))
    return add(name + "Configurations", "XCConfigurationList", buildConfigurations=variants,
               defaultConfigurationIsVisible=0, defaultConfigurationName="Release")

def main():
    app_files = sorted((ROOT / "PanelReader").rglob("*.swift"))
    test_files = sorted((ROOT / "PanelReaderTests").glob("*.swift"))
    app_refs, app_build, test_refs, test_build = [], [], [], []
    for files, group, refs, build in [(app_files, "App", app_refs, app_build), (test_files, "Tests", test_refs, test_build)]:
        directory = ROOT / ("PanelReader" if group == "App" else "PanelReaderTests")
        for file in files:
            name = group + file.relative_to(directory).as_posix()
            reference = add(name + "Ref", "PBXFileReference", lastKnownFileType="sourcecode.swift",
                            path=file.relative_to(directory).as_posix(), sourceTree="<group>")
            refs.append(reference)
            build.append(add(name + "Build", "PBXBuildFile", fileRef=reference))

    resource_refs, resource_build = [], []
    for filename, kind in [("Assets.xcassets", "folder.assetcatalog"), ("PrivacyInfo.xcprivacy", "text.xml")]:
        if not (ROOT / "PanelReader" / filename).exists():
            raise SystemExit(f"Missing resource: {filename}")
        reference = add(filename + "Ref", "PBXFileReference", lastKnownFileType=kind, path=filename, sourceTree="<group>")
        resource_refs.append(reference)
        resource_build.append(add(filename + "Build", "PBXBuildFile", fileRef=reference))
    info = add("InfoRef", "PBXFileReference", lastKnownFileType="text.plist.xml", path="Info.plist", sourceTree="<group>")
    app_group = add("AppGroup", "PBXGroup", children=app_refs + resource_refs + [info], path="PanelReader", sourceTree="<group>")
    tests_group = add("TestsGroup", "PBXGroup", children=test_refs, path="PanelReaderTests", sourceTree="<group>")
    app_product = add("AppProduct", "PBXFileReference", explicitFileType="wrapper.application", includeInIndex=0,
                      path="PanelReader.app", sourceTree="BUILT_PRODUCTS_DIR")
    tests_product = add("TestsProduct", "PBXFileReference", explicitFileType="wrapper.cfbundle", includeInIndex=0,
                        path="PanelReaderTests.xctest", sourceTree="BUILT_PRODUCTS_DIR")
    products = add("Products", "PBXGroup", children=[app_product, tests_product], name="Products", sourceTree="<group>")
    main_group = add("MainGroup", "PBXGroup", children=[app_group, tests_group, products], sourceTree="<group>")

    project_settings = {
        "CLANG_ENABLE_MODULES": "YES", "IPHONEOS_DEPLOYMENT_TARGET": "17.0", "SDKROOT": "iphoneos",
        "SWIFT_VERSION": "5.0", "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    }
    project_configs = configurations("Project", project_settings,
        {"DEBUG_INFORMATION_FORMAT": "dwarf", "SWIFT_OPTIMIZATION_LEVEL": "-Onone", "ENABLE_TESTABILITY": "YES"},
        {"DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym", "SWIFT_OPTIMIZATION_LEVEL": "-O", "SWIFT_COMPILATION_MODE": "wholemodule"})
    app_configs = configurations("App", {
        "PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_BUNDLE_IDENTIFIER": "com.example.panelreader",
        "INFOPLIST_FILE": "PanelReader/Info.plist", "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CURRENT_PROJECT_VERSION": "1", "MARKETING_VERSION": "0.1.0",
        "TARGETED_DEVICE_FAMILY": "1,2", "CODE_SIGN_STYLE": "Automatic", "DEVELOPMENT_TEAM": "",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
    })
    test_configs = configurations("Tests", {
        "PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_BUNDLE_IDENTIFIER": "com.example.panelreader.tests",
        "GENERATE_INFOPLIST_FILE": "YES", "TARGETED_DEVICE_FAMILY": "1,2",
        "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/PanelReader.app/PanelReader", "BUNDLE_LOADER": "$(TEST_HOST)",
        "CODE_SIGN_STYLE": "Automatic", "DEVELOPMENT_TEAM": "",
    })
    phases = {}
    for name, source_files, resources in [("App", app_build, resource_build), ("Tests", test_build, [])]:
        phases[name] = [add(name + suffix, isa, buildActionMask=2147483647, files=files, runOnlyForDeploymentPostprocessing=0)
            for suffix, isa, files in [("Sources", "PBXSourcesBuildPhase", source_files),
                                       ("Frameworks", "PBXFrameworksBuildPhase", []),
                                       ("Resources", "PBXResourcesBuildPhase", resources)]]
    app_target = add("AppTarget", "PBXNativeTarget", buildConfigurationList=app_configs, buildPhases=phases["App"],
                     buildRules=[], dependencies=[], name="PanelReader", productName="PanelReader", productReference=app_product,
                     productType="com.apple.product-type.application")
    proxy = add("AppProxy", "PBXContainerItemProxy", containerPortal=identifier("Project"), proxyType=1,
                remoteGlobalIDString=app_target, remoteInfo="PanelReader")
    dependency = add("AppDependency", "PBXTargetDependency", target=app_target, targetProxy=proxy)
    test_target = add("TestsTarget", "PBXNativeTarget", buildConfigurationList=test_configs, buildPhases=phases["Tests"],
                      buildRules=[], dependencies=[dependency], name="PanelReaderTests", productName="PanelReaderTests",
                      productReference=tests_product, productType="com.apple.product-type.bundle.unit-test")
    project_id = add("Project", "PBXProject", attributes={
        "LastUpgradeCheck": "1600", "BuildIndependentTargetsInParallel": "YES",
        "TargetAttributes": {app_target: {"CreatedOnToolsVersion": "16.0"},
                             test_target: {"CreatedOnToolsVersion": "16.0", "TestTargetID": app_target}},
    }, buildConfigurationList=project_configs, compatibilityVersion="Xcode 14.0", developmentRegion="en",
       hasScannedForEncodings=0, knownRegions=["en", "Base"], mainGroup=main_group, productRefGroup=products,
       projectDirPath="", projectRoot="", targets=[app_target, test_target])

    # Catch a missing target, resource, source, or configuration before writing the project.
    assert app_files and test_files
    for obj in objects.values():
        for key in ["fileRef", "target", "targetProxy", "containerPortal", "buildConfigurationList", "productReference", "mainGroup", "productRefGroup"]:
            if key in obj:
                assert obj[key] in objects, (key, obj[key])
        for key in ["children", "files", "buildPhases", "dependencies", "targets", "buildConfigurations"]:
            for reference in obj.get(key, []):
                assert reference in objects, (key, reference)
    PROJECT.mkdir(exist_ok=True)
    document = {"archiveVersion": 1, "classes": {}, "objectVersion": 56, "objects": objects, "rootObject": project_id}
    (PROJECT / "project.pbxproj").write_text("// !$*UTF8*$!\n" + encode(document) + "\n", encoding="utf-8")

    scheme = ET.Element("Scheme", LastUpgradeVersion="1600", version="1.3")
    def reference(parent, target, name, filename):
        ET.SubElement(parent, "BuildableReference", BuildableIdentifier="primary", BlueprintIdentifier=target,
                      BuildableName=filename, BlueprintName=name, ReferencedContainer="container:PanelReader.xcodeproj")
    build = ET.SubElement(scheme, "BuildAction", parallelizeBuildables="YES", buildImplicitDependencies="YES")
    entries = ET.SubElement(build, "BuildActionEntries")
    for target, name, filename, testing_only in [(app_target, "PanelReader", "PanelReader.app", False),
                                                (test_target, "PanelReaderTests", "PanelReaderTests.xctest", True)]:
        flags = {"buildForTesting": "YES", **{key: "NO" if testing_only else "YES" for key in
                 ["buildForRunning", "buildForProfiling", "buildForArchiving", "buildForAnalyzing"]}}
        reference(ET.SubElement(entries, "BuildActionEntry", **flags), target, name, filename)
    tests = ET.SubElement(scheme, "TestAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB",
                          selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", shouldUseLaunchSchemeArgsEnv="YES")
    testables = ET.SubElement(tests, "Testables")
    reference(ET.SubElement(testables, "TestableReference", skipped="NO"), test_target, "PanelReaderTests", "PanelReaderTests.xctest")
    launch = ET.SubElement(scheme, "LaunchAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB",
                           selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", launchStyle="0", useCustomWorkingDirectory="NO",
                           ignoresPersistentStateOnLaunch="NO", debugDocumentVersioning="YES", allowLocationSimulation="YES")
    reference(ET.SubElement(launch, "BuildableProductRunnable", runnableDebuggingMode="0"), app_target, "PanelReader", "PanelReader.app")
    profile = ET.SubElement(scheme, "ProfileAction", buildConfiguration="Release", shouldUseLaunchSchemeArgsEnv="YES",
                            savedToolIdentifier="", useCustomWorkingDirectory="NO", debugDocumentVersioning="YES")
    reference(ET.SubElement(profile, "BuildableProductRunnable", runnableDebuggingMode="0"), app_target, "PanelReader", "PanelReader.app")
    ET.SubElement(scheme, "AnalyzeAction", buildConfiguration="Debug")
    ET.SubElement(scheme, "ArchiveAction", buildConfiguration="Release", revealArchiveInOrganizer="YES")
    scheme_directory = PROJECT / "xcshareddata" / "xcschemes"
    scheme_directory.mkdir(parents=True, exist_ok=True)
    ET.indent(scheme)
    ET.ElementTree(scheme).write(scheme_directory / "PanelReader.xcscheme", encoding="utf-8", xml_declaration=True)
    print(f"Generated PanelReader.xcodeproj: {len(app_files)} app source files, {len(test_files)} test source files.")

if __name__ == "__main__":
    main()
