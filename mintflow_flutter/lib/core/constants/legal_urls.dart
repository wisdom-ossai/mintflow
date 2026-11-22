/// Public legal / support URLs for App Store compliance.
///
/// Served from the production API host until `mintflow.app` DNS is attached.
/// Keep ASC listing, paywall, and privacy screen in sync with these.
class MintflowLegalUrls {
  static const base = 'https://mintflow-api.up.railway.app';

  static final privacy = Uri.parse('$base/privacy');
  static final terms = Uri.parse('$base/terms');
  static final support = Uri.parse('$base/support');
}
