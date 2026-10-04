#!/usr/bin/env python3
import json, pathlib, plistlib
root = pathlib.Path(__file__).resolve().parent
objects = {}
def obj(isa, **values):
    key = f'{len(objects)+1:024X}'
    objects[key] = dict(isa=isa, **values)
    return key
def file(path, kind): return obj('PBXFileReference', lastKnownFileType=kind, path=path, sourceTree='SOURCE_ROOT')
def build(ref, **extra): return obj('PBXBuildFile', fileRef=ref, **extra)
shared = file('Sources/Shared/Snapshot.swift', 'sourcecode.swift')
mail_link = file('Sources/Shared/MailLink.swift', 'sourcecode.swift')
app_sources = [file('Sources/App/'+p, 'sourcecode.swift') for p in ['UnreadMailApp.swift','MailReader.swift','MailRefresh.swift','AgentStatus.swift','BackgroundRefresh.swift','SettingsApplication.swift']]
widget_source = file('Sources/Widget/UnreadMailWidget.swift', 'sourcecode.swift')
widget_config = file('Sources/Widget/MailConfiguration.swift', 'sourcecode.swift')
script = file('Sources/App/ReadMail.js','sourcecode.javascript')
app_product = obj('PBXFileReference', explicitFileType='wrapper.application', path='Mail Widgets.app', sourceTree='BUILT_PRODUCTS_DIR')
widget_product = obj('PBXFileReference', explicitFileType='wrapper.app-extension', path='UnreadMailWidget.appex', sourceTree='BUILT_PRODUCTS_DIR')
products = obj('PBXGroup', children=[app_product, widget_product], name='Products', sourceTree='<group>')
main_group = obj('PBXGroup', children=[shared,mail_link,*app_sources,widget_source,widget_config,script,products], sourceTree='<group>')
def configs(settings):
    ids = [obj('XCBuildConfiguration', name=name, buildSettings={**settings,'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if name=='Debug' else '-O'}) for name in ['Debug','Release']]
    return obj('XCConfigurationList', buildConfigurations=ids, defaultConfigurationIsVisible=0, defaultConfigurationName='Debug')
common = {'SDKROOT':'macosx','MACOSX_DEPLOYMENT_TARGET':'14.0','SWIFT_VERSION':'5.0','CODE_SIGN_IDENTITY':'-','CODE_SIGN_STYLE':'Manual','ENABLE_HARDENED_RUNTIME':'YES','COMBINE_HIDPI_IMAGES':'YES','GENERATE_INFOPLIST_FILE':'NO','CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'1.0','SWIFT_EMIT_LOC_STRINGS':'NO'}
widget_settings = {**common,'PRODUCT_NAME':'UnreadMailWidget','PRODUCT_BUNDLE_IDENTIFIER':'local.alexbp.UnreadMail.Widget','INFOPLIST_FILE':'Config/Widget-Info.plist','CODE_SIGN_ENTITLEMENTS':'Config/Widget.entitlements','APPLICATION_EXTENSION_API_ONLY':'YES','SKIP_INSTALL':'YES','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'WIDGET_EXTENSION','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/../Frameworks @executable_path/../../../../Frameworks'}
app_settings = {**common,'PRODUCT_NAME':'Mail Widgets','PRODUCT_BUNDLE_IDENTIFIER':'local.alexbp.UnreadMail','INFOPLIST_FILE':'Config/App-Info.plist','CODE_SIGN_ENTITLEMENTS':'Config/App.entitlements','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/../Frameworks'}
def phase(kind, files): return obj(kind, buildActionMask=2147483647, files=files, runOnlyForDeploymentPostprocessing=0)
widget_target = obj('PBXNativeTarget', buildConfigurationList=configs(widget_settings), buildPhases=[phase('PBXSourcesBuildPhase',[build(shared),build(widget_config),build(widget_source)]),phase('PBXFrameworksBuildPhase',[])], buildRules=[], dependencies=[], name='UnreadMailWidget', productName='UnreadMailWidget', productReference=widget_product, productType='com.apple.product-type.app-extension')
dep = obj('PBXTargetDependency', target=widget_target)
embed = obj('PBXCopyFilesBuildPhase', buildActionMask=2147483647, dstPath='',dstSubfolderSpec=13, files=[build(widget_product,settings={'ATTRIBUTES':['RemoveHeadersOnCopy']})], name='Embed App Extensions',runOnlyForDeploymentPostprocessing=0)
app_target = obj('PBXNativeTarget',buildConfigurationList=configs(app_settings),buildPhases=[phase('PBXSourcesBuildPhase',[build(shared),build(mail_link),*[build(f) for f in app_sources]]),phase('PBXResourcesBuildPhase',[build(script)]),phase('PBXFrameworksBuildPhase',[]),embed],buildRules=[],dependencies=[dep],name='UnreadMail',productName='Mail Widgets',productReference=app_product,productType='com.apple.product-type.application')
project = obj('PBXProject',attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'2700'},buildConfigurationList=configs({}),compatibilityVersion='Xcode 14.0',developmentRegion='en',hasScannedForEncodings=0,knownRegions=['en','Base'],mainGroup=main_group,productRefGroup=products,projectDirPath='',projectRoot='',targets=[app_target,widget_target])
def serialize(value, depth=0):
    if isinstance(value,dict): return '{\n'+''.join('\t'*(depth+1)+json.dumps(str(k))+' = '+serialize(v,depth+1)+';\n' for k,v in value.items())+'\t'*depth+'}'
    if isinstance(value,list): return '('+', '.join(serialize(x,depth+1) for x in value)+')'
    if isinstance(value,int): return str(value)
    return json.dumps(value)
folder=root/'UnreadMail.xcodeproj'; folder.mkdir(exist_ok=True)
(folder/'project.pbxproj').write_text('// !$*UTF8*$!\n'+serialize({'archiveVersion':1,'classes':{},'objectVersion':56,'objects':objects,'rootObject':project}))
base={'CFBundleDevelopmentRegion':'en','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0','CFBundleName':'$(PRODUCT_NAME)','CFBundleShortVersionString':'1.0','CFBundleVersion':'1','LSMinimumSystemVersion':'$(MACOSX_DEPLOYMENT_TARGET)'}
app={**base,'CFBundleDisplayName':'Mail Widgets','CFBundlePackageType':'APPL','NSPrincipalClass':'NSApplication','NSAppleEventsUsageDescription':'Mail Widgets reads the sender, subject and date of inbox messages to display them in your desktop widget.','CFBundleURLTypes':[{'CFBundleURLName':'Mail Widgets','CFBundleURLSchemes':['unreadmail']}],'LSApplicationCategoryType':'public.app-category.productivity'}
widget={**base,'CFBundleDisplayName':'Mail Widgets','CFBundlePackageType':'XPC!','NSExtension':{'NSExtensionPointIdentifier':'com.apple.widgetkit-extension'}}
for name,data in [('App',app),('Widget',widget)]:
    with (root/'Config'/f'{name}-Info.plist').open('wb') as f: plistlib.dump(data,f)
print('Generated UnreadMail.xcodeproj')
