import 'package:get/get.dart';
import '../../group/controller/group_controller.dart'; // <- Ruta corregida

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<GroupController>(() => GroupController(), fenix: true);
  }
}
