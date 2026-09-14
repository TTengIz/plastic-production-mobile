class ApiConfig {
  static const String baseUrl = 'http://api.crystal-box.ru/API';
  
  static const String login = 'http://api.crystal-box.ru/API/auth/login.php';
  static const String register = 'http://api.crystal-box.ru/API/auth/register.php';
  static const String startShift = 'http://api.crystal-box.ru/API/shifts/start.php';
  static const String endShift = 'http://api.crystal-box.ru/API/shifts/end_shift.php';
  static const String getShifts = 'http://api.crystal-box.ru/API/shifts/get_shifts.php';
  static const String checkViolations = 'http://api.crystal-box.ru/API/shifts/check_violations.php';
  static const String getViolations = 'http://api.crystal-box.ru/API/shifts/get_violations.php';
  
  // Production
  static const String productionReport = 'http://api.crystal-box.ru/API/production/report.php';
  static const String getProductionReports = 'http://api.crystal-box.ru/API/production/get_reports.php';
  
  // Warehouse
  static const String getMaterials = 'http://api.crystal-box.ru/API/warehouse/get_materials.php';
  static const String addMaterial = 'http://api.crystal-box.ru/API/warehouse/add_material.php';
  static const String updateMaterial = 'http://api.crystal-box.ru/API/warehouse/update_material.php';
  static const String deleteMaterial = 'http://api.crystal-box.ru/API/warehouse/delete_material.php';
  static const String getBlanks = 'http://api.crystal-box.ru/API/warehouse/get_blanks.php';
  static const String addBlanks = 'http://api.crystal-box.ru/API/warehouse/add_blanks.php';
  static const String updateBlanks = 'http://api.crystal-box.ru/API/warehouse/update_blanks.php';
  static const String deleteBlanks = 'http://api.crystal-box.ru/API/warehouse/delete_blanks.php';
  static const String getFinishedGoods = 'http://api.crystal-box.ru/API/warehouse/get_finished_goods.php';
  
  static const String rawMaterials = 'http://api.crystal-box.ru/API/warehouse/raw.php';
  static const String blanks = 'http://api.crystal-box.ru/API/warehouse/blanks.php';
  
  // Recipes
  static const String getRecipes = 'http://api.crystal-box.ru/API/recipes/get_recipes.php';
  static const String addRecipe = 'http://api.crystal-box.ru/API/recipes/add_recipe.php';
  static const String updateRecipe = 'http://api.crystal-box.ru/API/recipes/update_recipe.php';
  static const String deleteRecipe = 'http://api.crystal-box.ru/API/recipes/delete_recipe.php';
  
  // Finance
  static const String getRates = 'http://api.crystal-box.ru/API/finance/get_rates.php';
  static const String setRate = 'http://api.crystal-box.ru/API/finance/set_rate.php';
  static const String getEarnings = 'http://api.crystal-box.ru/API/finance/get_earnings.php';
  static const String sendReportEmail = 'http://api.crystal-box.ru/API/finance/send_report_email.php';
  
  // Time Off
  static const String getTimeOff = 'http://api.crystal-box.ru/API/time_off/get_time_off.php';
  static const String addTimeOff = 'http://api.crystal-box.ru/API/time_off/add_time_off.php';
  static const String deleteTimeOff = 'http://api.crystal-box.ru/API/time_off/delete_time_off.php';
  
  // Account
  static const String deleteAccount = 'http://api.crystal-box.ru/API/account/delete.php';
  static const String updateProfile = 'http://api.crystal-box.ru/API/account/update.php';
  
    // Monitoring
  static const String getDailyActivity = 'http://api.crystal-box.ru/API/monitoring/get_daily_activity.php';

  // Media
  static const String deleteMedia = 'http://api.crystal-box.ru/API/media/delete_media.php';

  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}

