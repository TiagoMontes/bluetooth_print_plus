//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <bluetooth_print_plus/bluetooth_print_plus_plugin.h>
#include <charset_converter/charset_converter_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) bluetooth_print_plus_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "BluetoothPrintPlusPlugin");
  bluetooth_print_plus_plugin_register_with_registrar(bluetooth_print_plus_registrar);
  g_autoptr(FlPluginRegistrar) charset_converter_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "CharsetConverterPlugin");
  charset_converter_plugin_register_with_registrar(charset_converter_registrar);
}
