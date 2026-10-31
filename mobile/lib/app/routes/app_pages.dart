import 'package:get/get.dart';

import '../../core/widgets/app_page_transition.dart';
import '../../views/login/login_view.dart';
import '../../views/products/product_form_view.dart';
import '../../views/contacts/categories_view.dart';
import '../../views/products/products_view.dart';
import '../../views/territories/territory_contacts_view.dart';
import '../../views/shell/main_shell_view.dart';
import '../bindings/login_binding.dart';
import '../bindings/categories_binding.dart';
import '../bindings/products_binding.dart';
import '../bindings/territory_contacts_binding.dart';
import '../bindings/visit_record_binding.dart';
import '../../views/admin/member_detail_view.dart';
import '../../views/admin/role_editor_view.dart';
import '../../views/reports/report_view.dart';
import '../../views/visits/visit_record_view.dart';
import '../bindings/shell_binding.dart';
import 'app_routes.dart';
import 'auth_guard.dart';

abstract class AppPages {
  /// Every route uses the same transition, so no screen is the odd one out.
  static final _transition = AppPageTransition();

  static final pages = <GetPage>[
    GetPage(
      name: AppRoutes.login,
      middlewares: [GuestGuard()],
      page: () => const LoginView(),
      binding: LoginBinding(),
      customTransition: _transition,
    ),
    GetPage(
      name: AppRoutes.home,
      middlewares: [AuthGuard()],
      page: () => const MainShellView(),
      binding: ShellBinding(),
      customTransition: _transition,
    ),
    GetPage(
      name: AppRoutes.categories,
      middlewares: [AuthGuard(), PermissionGuard('contacts.read')],
      page: () => const CategoriesView(),
      binding: CategoriesBinding(),
      customTransition: _transition,
    ),
    GetPage(
      name: AppRoutes.products,
      middlewares: [AuthGuard(), PermissionGuard('products.read')],
      page: () => const ProductsView(),
      binding: ProductsBinding(),
      customTransition: _transition,
    ),
    GetPage(
      name: AppRoutes.productNew,
      middlewares: [AuthGuard(), PermissionGuard('products.manage')],
      page: () => const ProductFormView(),
      binding: ProductFormBinding(),
      customTransition: _transition,
    ),
    GetPage(
      name: AppRoutes.productEdit,
      middlewares: [AuthGuard(), PermissionGuard('products.manage')],
      page: () => const ProductFormView(),
      binding: ProductFormBinding(),
      customTransition: _transition,
    ),
    GetPage(
      name: AppRoutes.memberDetail,
      middlewares: [AuthGuard(), PermissionGuard('users.read')],
      page: () => const MemberDetailView(),
      customTransition: _transition,
    ),
    GetPage(
      name: AppRoutes.roleEditor,
      middlewares: [AuthGuard(), PermissionGuard('roles.manage')],
      page: () => const RoleEditorView(),
      customTransition: _transition,
    ),
    GetPage(
      name: AppRoutes.report,
      middlewares: [AuthGuard()],
      page: () => const ReportView(),
      customTransition: _transition,
    ),
    GetPage(
      name: AppRoutes.visitRecord,
      middlewares: [AuthGuard(), PermissionGuard('visits.manage')],
      page: () => const VisitRecordView(),
      binding: VisitRecordBinding(),
      customTransition: _transition,
    ),
    GetPage(
      name: AppRoutes.territoryContacts,
      middlewares: [AuthGuard(), PermissionGuard('contacts.read')],
      page: () => const TerritoryContactsView(),
      binding: TerritoryContactsBinding(),
      customTransition: _transition,
    ),
  ];
}
