import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MonitoringSheetApp(),
    ),
  );
}

class MonitoringSheetApp extends StatelessWidget {
  const MonitoringSheetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitoring Sheet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

enum UserRole { management, employee }

enum AttendanceStatus { pending, approved, declined }

class ValidationException implements Exception {
  const ValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ManagementAccount {
  const ManagementAccount({
    required this.username,
    required this.password,
    required this.displayName,
  });

  final String username;
  final String password;
  final String displayName;
}

class Employee {
  const Employee({
    required this.id,
    required this.name,
    required this.username,
    required this.scheduledStart,
    required this.approveUntil,
    required this.hourlySalary,
  });

  final String id;
  final String name;
  final String username;
  final TimeOfDay scheduledStart;
  final TimeOfDay approveUntil;
  final double hourlySalary;
}

class AttendanceRecord {
  AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.inTime,
    required this.outTime,
    required this.task,
    required this.designation,
    required this.approveCutoff,
    required this.status,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime date;
  final TimeOfDay inTime;
  final TimeOfDay outTime;
  final String task;
  final String designation;
  final TimeOfDay approveCutoff;
  AttendanceStatus status;

  int get workedMinutes =>
      timeOfDayToMinutes(outTime) - timeOfDayToMinutes(inTime);

  Duration get workedDuration => Duration(minutes: workedMinutes);

  bool get beyondApproveTime =>
      timeOfDayToMinutes(outTime) > timeOfDayToMinutes(approveCutoff);

  Duration get overtime => beyondApproveTime
      ? Duration(
          minutes:
              timeOfDayToMinutes(outTime) - timeOfDayToMinutes(approveCutoff),
        )
      : Duration.zero;
}

class EmployeeHoursSummary {
  EmployeeHoursSummary({
    required this.employee,
    required this.approvedMinutes,
    required this.pendingMinutes,
    required this.approvedEntries,
    required this.pendingEntries,
  });

  final Employee employee;
  final int approvedMinutes;
  final int pendingMinutes;
  final int approvedEntries;
  final int pendingEntries;

  Duration get approvedDuration => Duration(minutes: approvedMinutes);

  Duration get pendingDuration => Duration(minutes: pendingMinutes);

  double get approvedHours => approvedMinutes / 60.0;

  double get estimatedPayroll => approvedHours * employee.hourlySalary;
}

class AppState extends ChangeNotifier {
  AppState() {
    _seedData();
  }

  final List<ManagementAccount> _managementAccounts = const [
    ManagementAccount(
      username: 'admin',
      password: 'admin123',
      displayName: 'HR Manager',
    ),
  ];

  final List<Employee> _employees = [];
  final List<AttendanceRecord> _attendanceRecords = [];
  int _attendanceSequence = 0;

  void _seedData() {
    final Employee employeeOne = Employee(
      id: 'EMP001',
      name: 'Asha Patel',
      username: 'asha',
      scheduledStart: const TimeOfDay(hour: 9, minute: 0),
      approveUntil: const TimeOfDay(hour: 17, minute: 0),
      hourlySalary: 28,
    );
    final Employee employeeTwo = Employee(
      id: 'EMP002',
      name: 'Rahul Sharma',
      username: 'rahul',
      scheduledStart: const TimeOfDay(hour: 10, minute: 0),
      approveUntil: const TimeOfDay(hour: 18, minute: 0),
      hourlySalary: 24,
    );

    _employees.addAll([employeeOne, employeeTwo]);

    _attendanceRecords.addAll([
      AttendanceRecord(
        id: _nextAttendanceId(),
        employeeId: employeeOne.id,
        employeeName: employeeOne.name,
        date: DateTime.now().subtract(const Duration(days: 1)),
        inTime: const TimeOfDay(hour: 9, minute: 5),
        outTime: const TimeOfDay(hour: 17, minute: 10),
        task: 'Client reporting & status sync',
        designation: 'Business Analyst',
        approveCutoff: employeeOne.approveUntil,
        status: AttendanceStatus.pending,
      ),
      AttendanceRecord(
        id: _nextAttendanceId(),
        employeeId: employeeOne.id,
        employeeName: employeeOne.name,
        date: DateTime.now().subtract(const Duration(days: 2)),
        inTime: const TimeOfDay(hour: 9, minute: 0),
        outTime: const TimeOfDay(hour: 17, minute: 0),
        task: 'Requirements workshop',
        designation: 'Business Analyst',
        approveCutoff: employeeOne.approveUntil,
        status: AttendanceStatus.approved,
      ),
      AttendanceRecord(
        id: _nextAttendanceId(),
        employeeId: employeeTwo.id,
        employeeName: employeeTwo.name,
        date: DateTime.now().subtract(const Duration(days: 1)),
        inTime: const TimeOfDay(hour: 10, minute: 0),
        outTime: const TimeOfDay(hour: 17, minute: 30),
        task: 'Module implementation',
        designation: 'Software Engineer',
        approveCutoff: employeeTwo.approveUntil,
        status: AttendanceStatus.approved,
      ),
    ]);
  }

  String _nextAttendanceId() {
    _attendanceSequence += 1;
    return 'ATT${_attendanceSequence.toString().padLeft(4, '0')}';
  }

  ManagementAccount? authenticateManager(String username, String password) {
    for (final account in _managementAccounts) {
      if (account.username.trim().toLowerCase() ==
              username.trim().toLowerCase() &&
          account.password == password) {
        return account;
      }
    }
    return null;
  }

  Employee? authenticateEmployee(String id, String username) {
    for (final employee in _employees) {
      if (employee.id.trim().toLowerCase() == id.trim().toLowerCase() &&
          employee.username.trim().toLowerCase() ==
              username.trim().toLowerCase()) {
        return employee;
      }
    }
    return null;
  }

  Employee addEmployee({
    required String id,
    required String name,
    required String username,
    required TimeOfDay scheduledStart,
    required TimeOfDay approveUntil,
    required double hourlySalary,
  }) {
    final trimmedId = id.trim();
    final trimmedName = name.trim();
    final trimmedUsername = username.trim();

    if (trimmedId.isEmpty) {
      throw const ValidationException('Employee ID is required.');
    }
    if (trimmedName.isEmpty) {
      throw const ValidationException('Employee name is required.');
    }
    if (trimmedUsername.isEmpty) {
      throw const ValidationException('Username is required.');
    }
    if (_employees.any(
      (employee) => employee.id.toLowerCase() == trimmedId.toLowerCase(),
    )) {
      throw ValidationException('Employee ID "$trimmedId" already exists.');
    }
    if (_employees.any(
      (employee) => employee.username.toLowerCase() ==
          trimmedUsername.toLowerCase(),
    )) {
      throw ValidationException('Username "$trimmedUsername" is already in use.');
    }
    if (timeOfDayToMinutes(approveUntil) <=
        timeOfDayToMinutes(scheduledStart)) {
      throw const ValidationException(
        'Approve time must be after the scheduled start time.',
      );
    }
    if (hourlySalary <= 0) {
      throw const ValidationException('Salary must be greater than zero.');
    }

    final employee = Employee(
      id: trimmedId,
      name: trimmedName,
      username: trimmedUsername,
      scheduledStart: scheduledStart,
      approveUntil: approveUntil,
      hourlySalary: hourlySalary,
    );
    _employees.add(employee);
    notifyListeners();
    return employee;
  }

  AttendanceRecord addAttendance({
    required Employee employee,
    required DateTime date,
    required TimeOfDay inTime,
    required TimeOfDay outTime,
    required String task,
    required String designation,
  }) {
    final cleanedTask = task.trim();
    final cleanedDesignation = designation.trim();
    if (cleanedTask.isEmpty) {
      throw const ValidationException('Task is required.');
    }
    if (cleanedDesignation.isEmpty) {
      throw const ValidationException('Designation is required.');
    }

    if (timeOfDayToMinutes(outTime) <= timeOfDayToMinutes(inTime)) {
      throw const ValidationException('Out time must be after the in time.');
    }

    final normalizedDate = DateTime(date.year, date.month, date.day);
    final isPending =
        timeOfDayToMinutes(outTime) > timeOfDayToMinutes(employee.approveUntil);

    final record = AttendanceRecord(
      id: _nextAttendanceId(),
      employeeId: employee.id,
      employeeName: employee.name,
      date: normalizedDate,
      inTime: inTime,
      outTime: outTime,
      task: cleanedTask,
      designation: cleanedDesignation,
      approveCutoff: employee.approveUntil,
      status: isPending ? AttendanceStatus.pending : AttendanceStatus.approved,
    );

    _attendanceRecords.add(record);
    notifyListeners();
    return record;
  }

  void updateAttendanceStatus(String attendanceId, AttendanceStatus status) {
    for (final record in _attendanceRecords) {
      if (record.id == attendanceId) {
        if (record.status != status) {
          record.status = status;
          notifyListeners();
        }
        return;
      }
    }
  }

  List<Employee> get employees => List.unmodifiable(_employees);

  List<AttendanceRecord> get attendanceRecords {
    final records = List<AttendanceRecord>.from(_attendanceRecords);
    records.sort((a, b) {
      final dateCompare = b.date.compareTo(a.date);
      if (dateCompare != 0) {
        return dateCompare;
      }
      return timeOfDayToMinutes(b.inTime) - timeOfDayToMinutes(a.inTime);
    });
    return records;
  }

  List<AttendanceRecord> attendanceForEmployee(String employeeId) {
    final records =
        _attendanceRecords.where((record) => record.employeeId == employeeId).toList();
    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  List<AttendanceRecord> get pendingAttendance => _attendanceRecords
      .where((record) => record.status == AttendanceStatus.pending)
      .toList();

  int get totalEmployees => _employees.length;

  int get pendingAttendanceCount => _attendanceRecords
      .where((record) => record.status == AttendanceStatus.pending)
      .length;

  Duration get totalApprovedDuration {
    final totalMinutes = _attendanceRecords
        .where((record) => record.status == AttendanceStatus.approved)
        .fold<int>(0, (sum, record) => sum + record.workedMinutes);
    return Duration(minutes: totalMinutes);
  }

  List<EmployeeHoursSummary> get employeeSummaries {
    final summaries = <EmployeeHoursSummary>[];
    for (final employee in _employees) {
      final records = attendanceForEmployee(employee.id);
      final approvedMinutes = records
          .where((record) => record.status == AttendanceStatus.approved)
          .fold<int>(0, (sum, record) => sum + record.workedMinutes);
      final pendingRecords =
          records.where((record) => record.status == AttendanceStatus.pending);
      final pendingMinutes =
          pendingRecords.fold<int>(0, (sum, record) => sum + record.workedMinutes);
      summaries.add(
        EmployeeHoursSummary(
          employee: employee,
          approvedMinutes: approvedMinutes,
          pendingMinutes: pendingMinutes,
          approvedEntries: records
              .where((record) => record.status == AttendanceStatus.approved)
              .length,
          pendingEntries: pendingRecords.length,
        ),
      );
    }
    summaries.sort((a, b) => a.employee.name.compareTo(b.employee.name));
    return summaries;
  }
}

String formatDate(DateTime date) {
  return DateFormat('EEE, dd MMM yyyy').format(date);
}

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) {
    return '${minutes}m';
  }
  if (minutes == 0) {
    return '${hours}h';
  }
  return '${hours}h ${minutes}m';
}

int timeOfDayToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

String describeStatus(AttendanceStatus status) {
  switch (status) {
    case AttendanceStatus.pending:
      return 'Pending';
    case AttendanceStatus.approved:
      return 'Approved';
    case AttendanceStatus.declined:
      return 'Declined';
  }
}

Color statusColor(AttendanceStatus status, ThemeData theme) {
  switch (status) {
    case AttendanceStatus.pending:
      return theme.colorScheme.tertiary;
    case AttendanceStatus.approved:
      return theme.colorScheme.primary;
    case AttendanceStatus.declined:
      return theme.colorScheme.error;
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  UserRole _selectedRole = UserRole.management;
  final TextEditingController _managerUsernameController =
      TextEditingController(text: 'admin');
  final TextEditingController _managerPasswordController =
      TextEditingController(text: 'admin123');
  final TextEditingController _employeeIdController = TextEditingController();
  final TextEditingController _employeeUsernameController =
      TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _managerUsernameController.dispose();
    _managerPasswordController.dispose();
    _employeeIdController.dispose();
    _employeeUsernameController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final appState = context.read<AppState>();
    setState(() {
      _errorMessage = null;
    });

    if (_selectedRole == UserRole.management) {
      final username = _managerUsernameController.text;
      final password = _managerPasswordController.text;
      if (username.trim().isEmpty || password.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter your management credentials.';
        });
        return;
      }
      final account = appState.authenticateManager(username, password);
      if (account == null) {
        setState(() {
          _errorMessage = 'Invalid management credentials. Try admin/admin123.';
        });
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ManagementHomeScreen(account: account),
        ),
      );
    } else {
      final employeeId = _employeeIdController.text;
      final username = _employeeUsernameController.text;
      if (employeeId.trim().isEmpty || username.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Please enter your employee ID and username.';
        });
        return;
      }
      final employee = appState.authenticateEmployee(employeeId, username);
      if (employee == null) {
        setState(() {
          _errorMessage =
              'Employee not found. Check the ID and username shared by HR.';
        });
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EmployeeHomeScreen(employee: employee),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 72,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Monitoring Sheet',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<UserRole>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Sign in as',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: UserRole.management,
                        child: Text('Upper Management'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.employee,
                        child: Text('Employee'),
                      ),
                    ],
                    onChanged: (role) {
                      if (role != null) {
                        setState(() {
                          _selectedRole = role;
                          _errorMessage = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_selectedRole == UserRole.management) ...[
                    TextFormField(
                      controller: _managerUsernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _managerPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Default credentials: admin / admin123',
                      style: theme.textTheme.bodySmall,
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _employeeIdController,
                      decoration: const InputDecoration(
                        labelText: 'Employee ID',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _employeeUsernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use the ID and username assigned by upper management.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _submit,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ManagementHomeScreen extends StatelessWidget {
  const ManagementHomeScreen({super.key, required this.account});

  final ManagementAccount account;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Welcome, ${account.displayName}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Overview'),
              Tab(icon: Icon(Icons.people_outline), text: 'Employees'),
              Tab(icon: Icon(Icons.schedule_outlined), text: 'Attendance'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ManagementOverviewTab(),
            EmployeeManagementTab(),
            AttendanceManagementTab(),
          ],
        ),
      ),
    );
  }
}

class EmployeeHomeScreen extends StatelessWidget {
  const EmployeeHomeScreen({super.key, required this.employee});

  final Employee employee;

  Future<void> _openAttendanceDialog(BuildContext context) async {
    final record = await showDialog<AttendanceRecord>(
      context: context,
      builder: (_) => AddAttendanceDialog(employee: employee),
    );
    if (record != null && context.mounted) {
      final message = record.status == AttendanceStatus.pending
          ? 'Attendance submitted and awaiting approval.'
          : 'Attendance recorded and approved.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Hello, ${employee.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAttendanceDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Attendance'),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          final records = appState.attendanceForEmployee(employee.id);
          final approvedMinutes = records
              .where((record) => record.status == AttendanceStatus.approved)
              .fold<int>(0, (sum, record) => sum + record.workedMinutes);
          final approvedDuration = Duration(minutes: approvedMinutes);
          final estimatedPayroll =
              (approvedMinutes / 60.0) * employee.hourlySalary;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Schedule',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Shift: ${formatEmployeeShift(context, employee)}',
                      ),
                      Text(
                        'Hourly salary: ${employee.hourlySalary.toStringAsFixed(2)}',
                      ),
                      const Divider(height: 24),
                      Text(
                        'Approved hours this period: ${formatDuration(approvedDuration)}',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        'Estimated pay: ${estimatedPayroll.toStringAsFixed(2)}',
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (records.isEmpty)
                Center(
                  child: Text(
                    'No attendance submitted yet. Tap "Add Attendance" to create one.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...records.map(
                  (record) => AttendanceCard(
                    record: record,
                    showEmployeeName: false,
                  ),
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

String formatEmployeeShift(BuildContext context, Employee employee) {
  final localizations = MaterialLocalizations.of(context);
  final start = localizations.formatTimeOfDay(employee.scheduledStart);
  final end = localizations.formatTimeOfDay(employee.approveUntil);
  return '$start - $end';
}

class ManagementOverviewTab extends StatelessWidget {
  const ManagementOverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final summaries = appState.employeeSummaries;
        final totalApprovedDuration = appState.totalApprovedDuration;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _OverviewStat(
                  icon: Icons.people_outline,
                  label: 'Employees',
                  value: appState.totalEmployees.toString(),
                  color: theme.colorScheme.primary,
                ),
                _OverviewStat(
                  icon: Icons.pending_actions_outlined,
                  label: 'Pending attendance',
                  value: appState.pendingAttendanceCount.toString(),
                  color: theme.colorScheme.tertiary,
                ),
                _OverviewStat(
                  icon: Icons.timer_outlined,
                  label: 'Approved hours',
                  value: formatDuration(totalApprovedDuration),
                  color: theme.colorScheme.secondary,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Employee workload and payroll',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (summaries.isEmpty)
              const Text('No employees yet. Add your first team member to begin.')
            else
              ...summaries.map((summary) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                summary.employee.name,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              summary.employee.id,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Username: ${summary.employee.username}'),
                        Text(
                          'Shift: ${formatEmployeeShift(context, summary.employee)}',
                        ),
                        Text(
                          'Hourly salary: ${summary.employee.hourlySalary.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            Text(
                              'Approved: ${formatDuration(summary.approvedDuration)} (${summary.approvedEntries} records)',
                            ),
                            Text(
                              'Pending: ${formatDuration(summary.pendingDuration)} (${summary.pendingEntries} records)',
                            ),
                            Text(
                              'Estimated pay: ${summary.estimatedPayroll.toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 200,
      child: Card(
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(color: color),
              ),
              Text(label, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
class EmployeeManagementTab extends StatelessWidget {
  const EmployeeManagementTab({super.key});

  Future<void> _openAddEmployeeDialog(BuildContext context) async {
    final employee = await showDialog<Employee>(
      context: context,
      builder: (_) => const AddEmployeeDialog(),
    );
    if (employee != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Employee ${employee.name} created.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final employees = appState.employees;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Employees',
                  style: theme.textTheme.titleMedium,
                ),
                FilledButton.icon(
                  onPressed: () => _openAddEmployeeDialog(context),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Register Employee'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (employees.isEmpty)
              const Text(
                'No employees registered yet. Create one to start tracking attendance.',
              )
            else
              ...employees.map(
                (employee) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                employee.name,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              employee.id,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Username: ${employee.username}'),
                        Text('Scheduled start: '
                            '${MaterialLocalizations.of(context).formatTimeOfDay(employee.scheduledStart)}'),
                        Text('Approve until: '
                            '${MaterialLocalizations.of(context).formatTimeOfDay(employee.approveUntil)}'),
                        Text(
                          'Hourly salary: ${employee.hourlySalary.toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}

class AttendanceManagementTab extends StatefulWidget {
  const AttendanceManagementTab({super.key});

  @override
  State<AttendanceManagementTab> createState() => _AttendanceManagementTabState();
}

class _AttendanceManagementTabState extends State<AttendanceManagementTab> {
  String? _selectedEmployeeId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final employees = appState.employees;
        final records = _selectedEmployeeId == null
            ? appState.attendanceRecords
            : appState.attendanceForEmployee(_selectedEmployeeId!);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _selectedEmployeeId,
                    decoration: const InputDecoration(
                      labelText: 'Filter by employee',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All employees'),
                      ),
                      ...employees.map(
                        (employee) => DropdownMenuItem<String?>(
                          value: employee.id,
                          child: Text('${employee.name} (${employee.id})'),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedEmployeeId = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (records.isEmpty)
              const Text('No attendance records found for the selected view.')
            else
              ...records.map(
                (record) => AttendanceCard(
                  record: record,
                  showEmployeeName: true,
                  onApprove: record.status == AttendanceStatus.pending
                      ? () {
                          context.read<AppState>().updateAttendanceStatus(
                                record.id,
                                AttendanceStatus.approved,
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Attendance ${record.id} approved.',
                              ),
                            ),
                          );
                        }
                      : null,
                  onDecline: record.status == AttendanceStatus.pending
                      ? () {
                          context.read<AppState>().updateAttendanceStatus(
                                record.id,
                                AttendanceStatus.declined,
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Attendance ${record.id} declined.',
                              ),
                            ),
                          );
                        }
                      : null,
                ),
              ),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}

class AddEmployeeDialog extends StatefulWidget {
  const AddEmployeeDialog({super.key});

  @override
  State<AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<AddEmployeeDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController();
  TimeOfDay? _scheduledStart;
  TimeOfDay? _approveUntil;
  String? _formError;

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _pickScheduledStart() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _scheduledStart ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (selected != null) {
      setState(() {
        _scheduledStart = selected;
      });
    }
  }

  Future<void> _pickApproveUntil() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _approveUntil ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (selected != null) {
      setState(() {
        _approveUntil = selected;
      });
    }
  }

  void _submit() {
    setState(() {
      _formError = null;
    });
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_scheduledStart == null || _approveUntil == null) {
      setState(() {
        _formError = 'Scheduled start and approve time are required.';
      });
      return;
    }
    final salary = double.tryParse(_salaryController.text.trim());
    if (salary == null) {
      setState(() {
        _formError = 'Enter a valid salary amount.';
      });
      return;
    }

    try {
      final employee = context.read<AppState>().addEmployee(
            id: _idController.text,
            name: _nameController.text,
            username: _usernameController.text,
            scheduledStart: _scheduledStart!,
            approveUntil: _approveUntil!,
            hourlySalary: salary,
          );
      Navigator.of(context).pop(employee);
    } on ValidationException catch (error) {
      setState(() {
        _formError = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Register new employee'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _idController,
                decoration: const InputDecoration(labelText: 'Employee ID'),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Employee ID is required';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Username is required';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _salaryController,
                decoration: const InputDecoration(labelText: 'Hourly salary'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Salary is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickScheduledStart,
                      child: Text(
                        _scheduledStart == null
                            ? 'Select scheduled start'
                            : 'Scheduled: ${MaterialLocalizations.of(context).formatTimeOfDay(_scheduledStart!)}',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickApproveUntil,
                      child: Text(
                        _approveUntil == null
                            ? 'Select approve time'
                            : 'Approve until: ${MaterialLocalizations.of(context).formatTimeOfDay(_approveUntil!)}',
                      ),
                    ),
                  ),
                ],
              ),
              if (_formError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _formError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class AddAttendanceDialog extends StatefulWidget {
  const AddAttendanceDialog({super.key, required this.employee});

  final Employee employee;

  @override
  State<AddAttendanceDialog> createState() => _AddAttendanceDialogState();
}

class _AddAttendanceDialogState extends State<AddAttendanceDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  late TimeOfDay _inTime;
  late TimeOfDay _outTime;
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  String? _formError;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _inTime = widget.employee.scheduledStart;
    _outTime = widget.employee.approveUntil;
  }

  @override
  void dispose() {
    _taskController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 1),
    );
    if (selected != null) {
      setState(() {
        _selectedDate = selected;
      });
    }
  }

  Future<void> _pickInTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _inTime,
    );
    if (selected != null) {
      setState(() {
        _inTime = selected;
      });
    }
  }

  Future<void> _pickOutTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _outTime,
    );
    if (selected != null) {
      setState(() {
        _outTime = selected;
      });
    }
  }

  void _submit() {
    setState(() {
      _formError = null;
    });
    if (!_formKey.currentState!.validate()) {
      return;
    }
    try {
      final record = context.read<AppState>().addAttendance(
            employee: widget.employee,
            date: _selectedDate,
            inTime: _inTime,
            outTime: _outTime,
            task: _taskController.text,
            designation: _designationController.text,
          );
      Navigator.of(context).pop(record);
    } on ValidationException catch (error) {
      setState(() {
        _formError = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    return AlertDialog(
      title: const Text('Add attendance'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: _pickDate,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Date: ${formatDate(_selectedDate)}'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickInTime,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('In time: ${localizations.formatTimeOfDay(_inTime)}'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickOutTime,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Out time: ${localizations.formatTimeOfDay(_outTime)}'),
                      ),
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: _taskController,
                decoration: const InputDecoration(labelText: 'Task summary'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Task is required';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _designationController,
                decoration: const InputDecoration(labelText: 'Designation'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Designation is required';
                  }
                  return null;
                },
              ),
              if (_formError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _formError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Attendance is automatically marked pending if the checkout time is later than '
                '${localizations.formatTimeOfDay(widget.employee.approveUntil)}.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

class AttendanceCard extends StatelessWidget {
  const AttendanceCard({
    super.key,
    required this.record,
    this.onApprove,
    this.onDecline,
    this.showEmployeeName = true,
  });

  final AttendanceRecord record;
  final VoidCallback? onApprove;
  final VoidCallback? onDecline;
  final bool showEmployeeName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showEmployeeName)
                        Text(
                          record.employeeName,
                          style: theme.textTheme.titleMedium,
                        ),
                      Text(
                        formatDate(record.date),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusChip(status: record.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Time: ${localizations.formatTimeOfDay(record.inTime)} - '
              '${localizations.formatTimeOfDay(record.outTime)} '
              '(${formatDuration(record.workedDuration)})',
            ),
            Text('Task: ${record.task}'),
            Text('Designation: ${record.designation}'),
            if (record.beyondApproveTime)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Submitted after the approved time window. '
                        '${record.overtime.inMinutes} minutes overtime.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            if (record.status == AttendanceStatus.pending &&
                (onApprove != null || onDecline != null))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    if (onApprove != null)
                      FilledButton(
                        onPressed: onApprove,
                        child: const Text('Approve'),
                      ),
                    if (onApprove != null && onDecline != null)
                      const SizedBox(width: 8),
                    if (onDecline != null)
                      OutlinedButton(
                        onPressed: onDecline,
                        child: const Text('Decline'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      backgroundColor: statusColor(status, theme).withOpacity(0.1),
      label: Text(
        describeStatus(status),
        style: TextStyle(color: statusColor(status, theme)),
      ),
    );
  }
}
