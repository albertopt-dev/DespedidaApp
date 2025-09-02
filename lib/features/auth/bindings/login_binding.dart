import 'package:get/get.dart';
import '../controller/login_controller.dart';

class LoginBinding extends Bindings {
  @override
  void dependencies() {
    // fenix:true => si el controlador se llega a disponer,
    // GetX lo recrea automáticamente cuando la ruta vuelve a necesitarlo.
    Get.lazyPut<LoginController>(() => LoginController(), fenix: true);
  }
}
