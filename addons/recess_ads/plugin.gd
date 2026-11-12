@tool
extends EditorPlugin
## Exportação Android: junta o plugin (recess_ads.aar), o SDK do Google Mobile
## Ads e o ID do app AdMob no manifesto. Precisa de "Usar build Gradle".

const APP_ID := "ca-app-pub-4311255826061303~3657630165"
const ADS_SDK := "com.google.android.gms:play-services-ads:23.6.0"

var _export: AdsExport


func _enter_tree() -> void:
	_export = AdsExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class AdsExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "RecessAds"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["recess_ads/bin/recess_ads.aar"])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([ADS_SDK])

	func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		# API 36: em tablet o Android ignora a trava de paisagem; esta opção mantém o jogo deitado
		return ('<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="%s"/>\n' % APP_ID) + \
			'<property android:name="android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY" android:value="true"/>\n'

	func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		# app para crianças (Famílias do Google Play): sem o ID de publicidade
		var out := ""
		for perm in ["com.google.android.gms.permission.AD_ID", "android.permission.ACCESS_ADSERVICES_AD_ID",
				"android.permission.ACCESS_ADSERVICES_ATTRIBUTION", "android.permission.ACCESS_ADSERVICES_TOPICS"]:
			out += '<uses-permission android:name="%s" tools:node="remove"/>\n' % perm
		return out
