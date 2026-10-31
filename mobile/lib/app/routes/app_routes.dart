abstract class AppRoutes {
  static const login = '/login';

  /// Enters the six-digit code from the reset email and a new password. The mobile or email is the route argument.
  static const passwordReset = '/login/reset';

  /// The signed-in landing screen: the bottom tabs.
  static const home = '/app';

  static const products = '/products';
  static const categories = '/categories';

  /// Creates a product. Editing uses [productEdit] with the product as the route argument.
  static const productNew = '/products/new';
  static const productEdit = '/products/edit';

  /// Every contact inside the zone or subzone passed as the route argument.
  static const territoryContacts = '/visits/contacts';

  /// One person's performance over the period. The person and period are the route argument.
  static const memberDetail = '/admin/performance/member';

  /// Creates or edits a role. The role is the route argument; none means a new role.
  static const roleEditor = '/admin/roles/edit';

  /// A full report, opened from a home card. The report kind is the route argument.
  static const report = '/reports';

  /// Records one call on the contact passed as the route argument.
  static const visitRecord = '/visits/record';
}
