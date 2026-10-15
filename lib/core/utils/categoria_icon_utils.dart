import 'package:flutter/material.dart';

/// Mantém os ícones de categoria iguais aos exibidos no Clubbar Client.
class CategoriaIconUtils {
  static const _iconesPorCodigo = <String, IconData>{
    'category': Icons.category_rounded,
    'water_drop': Icons.water_drop_rounded,
    'local_drink': Icons.local_drink_rounded,
    'local_cafe': Icons.local_cafe_rounded,
    'bolt': Icons.bolt_rounded,
    'sports_bar': Icons.sports_bar_rounded,
    'no_drinks': Icons.no_drinks_rounded,
    'local_bar': Icons.local_bar_rounded,
    'liquor': Icons.liquor_rounded,
    'wine_bar': Icons.wine_bar_rounded,
    'coffee': Icons.coffee_rounded,
    'emoji_nature': Icons.emoji_nature_rounded,
    'emoji_food_beverage': Icons.emoji_food_beverage_rounded,
    'soup_kitchen': Icons.soup_kitchen_rounded,
    'tapas': Icons.tapas_rounded,
    'restaurant': Icons.restaurant_rounded,
    'lunch_dining': Icons.lunch_dining_rounded,
    'skillet': Icons.fastfood_rounded,
    'kebab_dining': Icons.kebab_dining_rounded,
    'outdoor_grill': Icons.outdoor_grill_rounded,
    'fastfood': Icons.fastfood_rounded,
    'local_pizza': Icons.local_pizza_rounded,
    'dinner_dining': Icons.dinner_dining_rounded,
    'eco': Icons.eco_rounded,
    'room_service': Icons.room_service_rounded,
    'groups': Icons.groups_rounded,
    'child_care': Icons.child_care_rounded,
    'restaurant_menu': Icons.restaurant_menu_rounded,
    'set_meal': Icons.set_meal_rounded,
    'grass': Icons.grass_rounded,
    'cake': Icons.cake_rounded,
    'cookie': Icons.cookie_rounded,
    'icecream': Icons.icecream_rounded,
    'inventory_2': Icons.inventory_2_rounded,
    'sell': Icons.sell_rounded,
    'celebration': Icons.celebration_rounded,
    'event_seat': Icons.event_seat_rounded,
    'table_restaurant': Icons.table_restaurant_rounded,
    'event': Icons.event_rounded,
    'festival': Icons.festival_rounded,
    'checkroom': Icons.checkroom_rounded,
    'redeem': Icons.redeem_rounded,
    'more_horiz': Icons.more_horiz_rounded,
  };

  static IconData porCategoria(String nome, String? codigoIcone) {
    final codigo = codigoIcone?.trim().toLowerCase();
    return _iconesPorCodigo[codigo] ?? porNome(nome);
  }

  static Color corPorNome(String nome) {
    final texto = nome.trim().toLowerCase();
    if (texto.contains('cerveja') || texto.contains('chopp')) {
      return const Color(0xFFAF6B00);
    }
    if (texto.contains('água') || texto.contains('agua')) {
      return const Color(0xFF087BAA);
    }
    if (texto.contains('refrigerante') || texto.contains('suco')) {
      return const Color(0xFF23813A);
    }
    if (texto.contains('vinho')) return const Color(0xFF8E2A5B);
    if (texto.contains('drink') ||
        texto.contains('coquetel') ||
        texto.contains('destilado')) {
      return const Color(0xFF7340A0);
    }
    if (texto.contains('pizza') ||
        texto.contains('lanche') ||
        texto.contains('hamburguer') ||
        texto.contains('hambúrguer')) {
      return const Color(0xFFCF4B22);
    }
    if (texto.contains('sobremesa') ||
        texto.contains('doce') ||
        texto.contains('bolo')) {
      return const Color(0xFFB83272);
    }
    if (texto.contains('café') || texto.contains('cafe')) {
      return const Color(0xFF79513A);
    }
    if (texto.contains('energético') || texto.contains('energetico')) {
      return const Color(0xFFB57900);
    }
    if (texto.contains('combo')) return const Color(0xFF28609B);
    return const Color(0xFF8C5A15);
  }

  static IconData porNome(String nome) {
    final texto = nome.trim().toLowerCase();
    if (texto.contains('cerveja') ||
        texto.contains('chopp') ||
        texto.contains('alcoólica') ||
        texto.contains('alcoolica')) {
      return Icons.sports_bar_rounded;
    }
    if (texto.contains('refrigerante')) return Icons.local_drink_rounded;
    if (texto.contains('água') || texto.contains('agua')) {
      return Icons.water_drop_rounded;
    }
    if (texto.contains('suco')) return Icons.local_cafe_rounded;
    if (texto.contains('lanche') ||
        texto.contains('hambúrguer') ||
        texto.contains('hamburguer')) {
      return Icons.lunch_dining_rounded;
    }
    if (texto.contains('porção') ||
        texto.contains('porcao') ||
        texto.contains('petisco')) {
      return Icons.fastfood_rounded;
    }
    if (texto.contains('pizza')) return Icons.local_pizza_rounded;
    if (texto.contains('sobremesa') ||
        texto.contains('doce') ||
        texto.contains('bolo')) {
      return Icons.cake_rounded;
    }
    if (texto.contains('café') || texto.contains('cafe')) {
      return Icons.coffee_rounded;
    }
    if (texto.contains('vinho')) return Icons.wine_bar_rounded;
    if (texto.contains('drink') ||
        texto.contains('coquetel') ||
        texto.contains('dose') ||
        texto.contains('destilado')) {
      return Icons.local_bar_rounded;
    }
    if (texto.contains('energético') || texto.contains('energetico')) {
      return Icons.bolt_rounded;
    }
    if (texto.contains('combo')) return Icons.inventory_2_rounded;
    return Icons.restaurant_menu_rounded;
  }
}
