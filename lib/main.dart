import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? initializationError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on Exception catch (error, stackTrace) {
    initializationError = 'Firebase initialization failed: $error';
    debugPrint(initializationError);
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(
        useFirestore: initializationError == null,
        initializationError: initializationError,
      ),
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
    required this.totalSalary,
    required this.scheduledStart,
    required this.approveInTime,
    required this.scheduledWorkingMinutes,
  });

  final String id;
  final String name;
  final String username;
  final double totalSalary;
  final TimeOfDay scheduledStart;
  final TimeOfDay approveInTime;
  final int scheduledWorkingMinutes;

  Duration get scheduledWorkingDuration =>
      Duration(minutes: scheduledWorkingMinutes);

  double get hourlyRate => scheduledWorkingMinutes == 0
      ? 0
      : totalSalary / (scheduledWorkingMinutes / 60);

  TimeOfDay get approveOutTime =>
      addMinutesToTimeOfDay(scheduledStart, scheduledWorkingMinutes);

  Map<String, Object?> toFirestore() => {
        'id': id,
        'name': name,
        'username': username,
        'totalSalary': totalSalary,
        'scheduledStartMinutes': timeOfDayToMinutes(scheduledStart),
        'approveInMinutes': timeOfDayToMinutes(approveInTime),
        'scheduledWorkingMinutes': scheduledWorkingMinutes,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory Employee.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return Employee(
      id: (data['id'] as String?)?.trim().isNotEmpty == true
          ? data['id'] as String
          : doc.id,
      name: (data['name'] as String?) ?? '',
      username: (data['username'] as String?) ?? '',
      totalSalary: (data['totalSalary'] as num?)?.toDouble() ?? 0,
      scheduledStart: minutesToTimeOfDay(
        (data['scheduledStartMinutes'] as num?)?.toInt() ?? 0,
      ),
      approveInTime: minutesToTimeOfDay(
        (data['approveInMinutes'] as num?)?.toInt() ?? 0,
      ),
      scheduledWorkingMinutes:
          (data['scheduledWorkingMinutes'] as num?)?.toInt() ?? 8 * 60,
    );
  }
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
    required this.approveInCutoff,
    required this.approveOutCutoff,
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
  final TimeOfDay approveInCutoff;
  final TimeOfDay approveOutCutoff;
  AttendanceStatus status;

  int get workedMinutes =>
      timeOfDayToMinutes(outTime) - timeOfDayToMinutes(inTime);

  Duration get workedDuration => Duration(minutes: workedMinutes);

  bool get lateCheckIn =>
      timeOfDayToMinutes(inTime) > timeOfDayToMinutes(approveInCutoff);

  Duration get lateBy => lateCheckIn
      ? Duration(
          minutes:
              timeOfDayToMinutes(inTime) - timeOfDayToMinutes(approveInCutoff),
        )
      : Duration.zero;

  bool get beyondApprovedCheckout => timeOfDayToMinutes(outTime) >
      timeOfDayToMinutes(approveOutCutoff);

  Duration get overtime => beyondApprovedCheckout
      ? Duration(
          minutes:
              timeOfDayToMinutes(outTime) - timeOfDayToMinutes(approveOutCutoff),
        )
      : Duration.zero;

  bool get beyondApproveTime => lateCheckIn || beyondApprovedCheckout;

  Map<String, Object?> toFirestore() => {
        'id': id,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'date': Timestamp.fromDate(
          DateTime(date.year, date.month, date.day),
        ),
        'inMinutes': timeOfDayToMinutes(inTime),
        'outMinutes': timeOfDayToMinutes(outTime),
        'task': task,
        'designation': designation,
        'approveInMinutes': timeOfDayToMinutes(approveInCutoff),
        'approveOutMinutes': timeOfDayToMinutes(approveOutCutoff),
        'status': status.name,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory AttendanceRecord.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final timestamp = data['date'];
    final date = timestamp is Timestamp
        ? timestamp.toDate()
        : DateTime.now();
    return AttendanceRecord(
      id: doc.id,
      employeeId: (data['employeeId'] as String?) ?? '',
      employeeName: (data['employeeName'] as String?) ?? '',
      date: DateTime(date.year, date.month, date.day),
      inTime: minutesToTimeOfDay((data['inMinutes'] as num?)?.toInt() ?? 0),
      outTime: minutesToTimeOfDay((data['outMinutes'] as num?)?.toInt() ?? 0),
      task: (data['task'] as String?) ?? '',
      designation: (data['designation'] as String?) ?? '',
      approveInCutoff:
          minutesToTimeOfDay((data['approveInMinutes'] as num?)?.toInt() ?? 0),
      approveOutCutoff:
          minutesToTimeOfDay((data['approveOutMinutes'] as num?)?.toInt() ?? 0),
      status: attendanceStatusFromString((data['status'] as String?) ?? ''),
    );
  }
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

  double get estimatedPayroll => approvedHours * employee.hourlyRate;
}

class AppState extends ChangeNotifier {
  AppState({
    bool useFirestore = true,
    FirebaseFirestore? firestore,
    String? initializationError,
  }) : _useFirestore = useFirestore {
    if (_useFirestore) {
      _firestore = firestore ?? FirebaseFirestore.instance;
      _initializeFirestoreListeners();
    } else {
      _loadError = initializationError ??
          'Unable to initialize Firebase. Please check your Firebase configuration.';
      _employeesLoaded = true;
      _attendanceLoaded = true;
    }
  }

  final bool _useFirestore;
  late final FirebaseFirestore _firestore;

  final List<ManagementAccount> _managementAccounts = const [
    ManagementAccount(
      username: 'admin',
      password: 'admin123',
      displayName: 'HR Manager',
    ),
  ];

  final List<Employee> _employees = [];
  final List<AttendanceRecord> _attendanceRecords = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _employeesSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _attendanceSubscription;
  bool _employeesLoaded = false;
  bool _attendanceLoaded = false;
  String? _loadError;

  bool get isLoading =>
      _useFirestore && (!_employeesLoaded || !_attendanceLoaded);

  bool get hasLoadError => _loadError != null;

  String? get loadError => _loadError;

  void _initializeFirestoreListeners() {
    _employeesSubscription = _firestore
        .collection('employees')
        .snapshots()
        .listen(
      (snapshot) {
        _employees
          ..clear();
        for (final doc in snapshot.docs) {
          try {
            _employees.add(Employee.fromFirestore(doc));
          } catch (error) {
            debugPrint('Failed to parse employee ${doc.id}: $error');
          }
        }
        _employeesLoaded = true;
        _loadError = null;
        notifyListeners();
      },
      onError: _handleFirestoreError,
    );

    _attendanceSubscription = _firestore
        .collection('attendance')
        .snapshots()
        .listen(
      (snapshot) {
        _attendanceRecords
          ..clear();
        for (final doc in snapshot.docs) {
          try {
            _attendanceRecords.add(AttendanceRecord.fromFirestore(doc));
          } catch (error) {
            debugPrint('Failed to parse attendance ${doc.id}: $error');
          }
        }
        _attendanceLoaded = true;
        _loadError = null;
        notifyListeners();
      },
      onError: _handleFirestoreError,
    );
  }

  void _handleFirestoreError(Object error, StackTrace stackTrace) {
    debugPrint('Firestore listener error: $error');
    _loadError =
        'Unable to load data from Firestore. Please check your Firebase configuration.';
    notifyListeners();
  }

  @override
  void dispose() {
    _employeesSubscription?.cancel();
    _attendanceSubscription?.cancel();
    super.dispose();
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
    final normalizedId = id.trim().toLowerCase();
    final normalizedUsername = username.trim().toLowerCase();
    for (final employee in _employees) {
      if (employee.id.trim().toLowerCase() == normalizedId &&
          employee.username.trim().toLowerCase() == normalizedUsername) {
        return employee;
      }
    }
    return null;
  }

  Future<Employee> addEmployee({
    required String id,
    required String name,
    required String username,
    required double totalSalary,
    required TimeOfDay scheduledStart,
    required TimeOfDay approveInTime,
    required int scheduledWorkingMinutes,
  }) async {
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
    if (totalSalary <= 0) {
      throw const ValidationException(
          'Total salary must be greater than zero.');
    }
    if (scheduledWorkingMinutes <= 0) {
      throw const ValidationException(
          'Scheduled working hours must be greater than zero.');
    }
    if (timeOfDayToMinutes(approveInTime) <
        timeOfDayToMinutes(scheduledStart)) {
      throw const ValidationException(
        'Approve in time cannot be earlier than the scheduled start time.',
      );
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
      throw ValidationException(
          'Username "$trimmedUsername" is already in use.');
    }

    final employee = Employee(
      id: trimmedId,
      name: trimmedName,
      username: trimmedUsername,
      totalSalary: totalSalary,
      scheduledStart: scheduledStart,
      approveInTime: approveInTime,
      scheduledWorkingMinutes: scheduledWorkingMinutes,
    );

    if (!_useFirestore) {
      throw const StateError(
        'Unable to add employees because Firestore is not available.',
      );
    }

    final docRef = _firestore.collection('employees').doc(trimmedId);
    await docRef.set(employee.toFirestore());
    return employee;
  }

  Future<AttendanceRecord> addAttendance({
    required Employee employee,
    required DateTime date,
    required TimeOfDay inTime,
    required TimeOfDay outTime,
    required String task,
    required String designation,
  }) async {
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
    final lateCheckIn =
        timeOfDayToMinutes(inTime) > timeOfDayToMinutes(employee.approveInTime);
    final exceededCheckout = timeOfDayToMinutes(outTime) >
        timeOfDayToMinutes(employee.approveOutTime);
    final status = (lateCheckIn || exceededCheckout)
        ? AttendanceStatus.pending
        : AttendanceStatus.approved;

    if (!_useFirestore) {
      throw const StateError(
        'Unable to add attendance because Firestore is not available.',
      );
    }

    final docRef = _firestore.collection('attendance').doc();
    final attendance = AttendanceRecord(
      id: docRef.id,
      employeeId: employee.id,
      employeeName: employee.name,
      date: normalizedDate,
      inTime: inTime,
      outTime: outTime,
      task: cleanedTask,
      designation: cleanedDesignation,
      approveInCutoff: employee.approveInTime,
      approveOutCutoff: employee.approveOutTime,
      status: status,
    );

    await docRef.set(attendance.toFirestore());
    return attendance;
  }

  Future<void> updateAttendanceStatus(
    String attendanceId,
    AttendanceStatus status,
  ) async {
    if (!_useFirestore) {
      throw const StateError(
        'Unable to update attendance because Firestore is not available.',
      );
    }

    await _firestore
        .collection('attendance')
        .doc(attendanceId)
        .update({'status': status.name});
  }

  List<Employee> get employees {
    final list = List<Employee>.from(_employees);
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

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
    final records = _attendanceRecords
        .where((record) => record.employeeId == employeeId)
        .toList();
    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  List<AttendanceRecord> get pendingAttendance => _attendanceRecords
      .where((record) => record.status == AttendanceStatus.pending)
      .toList();

  int get totalEmployees => _employees.length;

  int get pendingAttendanceCount => pendingAttendance.length;

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
      final pendingMinutes = pendingRecords.fold<int>(
        0,
        (sum, record) => sum + record.workedMinutes,
      );
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

TimeOfDay minutesToTimeOfDay(int minutes) {
  final totalMinutes = minutes % (24 * 60);
  final normalized = totalMinutes < 0 ? totalMinutes + 24 * 60 : totalMinutes;
  final hours = normalized ~/ 60;
  final remainingMinutes = normalized % 60;
  return TimeOfDay(hour: hours, minute: remainingMinutes);
}

TimeOfDay addMinutesToTimeOfDay(TimeOfDay time, int minutesToAdd) {
  final total = timeOfDayToMinutes(time) + minutesToAdd;
  return minutesToTimeOfDay(total);
}

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

AttendanceStatus attendanceStatusFromString(String value) {
  final normalized = value.trim().toLowerCase();
  for (final status in AttendanceStatus.values) {
    if (status.name == normalized) {
      return status;
    }
  }
  switch (normalized) {
    case 'approved':
      return AttendanceStatus.approved;
    case 'declined':
      return AttendanceStatus.declined;
    default:
      return AttendanceStatus.pending;
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
    final appState = context.watch<AppState>();

    if (appState.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connecting to the attendance database...'),
            ],
          ),
        ),
      );
    }

    if (appState.hasLoadError) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Unable to load data from Firestore.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (appState.loadError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    appState.loadError!,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Please verify your Firebase configuration and restart the app.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

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
              (approvedMinutes / 60.0) * employee.hourlyRate;

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
                        'Approve in time: ${MaterialLocalizations.of(context).formatTimeOfDay(employee.approveInTime)}',
                      ),
                      Text(
                        'Scheduled hours: ${formatDuration(employee.scheduledWorkingDuration)}',
                      ),
                      Text(
                        'Total salary per shift: ${employee.totalSalary.toStringAsFixed(2)}',
                      ),
                      Text(
                        'Hourly rate: ${employee.hourlyRate.toStringAsFixed(2)}',
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
  final end = localizations.formatTimeOfDay(employee.approveOutTime);
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
                          'Approve in time: ${MaterialLocalizations.of(context).formatTimeOfDay(summary.employee.approveInTime)}',
                        ),
                        Text(
                          'Scheduled hours: ${formatDuration(summary.employee.scheduledWorkingDuration)}',
                        ),
                        Text(
                          'Total salary per shift: ${summary.employee.totalSalary.toStringAsFixed(2)}',
                        ),
                        Text(
                          'Hourly rate: ${summary.employee.hourlyRate.toStringAsFixed(2)}',
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
        final theme = Theme.of(context);
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
                        Text('Approve in time: '
                            '${MaterialLocalizations.of(context).formatTimeOfDay(employee.approveInTime)}'),
                        Text('Approve out time: '
                            '${MaterialLocalizations.of(context).formatTimeOfDay(employee.approveOutTime)}'),
                        Text(
                          'Scheduled hours: ${formatDuration(employee.scheduledWorkingDuration)}',
                        ),
                        Text(
                          'Total salary per shift: ${employee.totalSalary.toStringAsFixed(2)}',
                        ),
                        Text(
                          'Hourly rate: ${employee.hourlyRate.toStringAsFixed(2)}',
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
                      ? () async {
                          try {
                            await context
                                .read<AppState>()
                                .updateAttendanceStatus(
                                  record.id,
                                  AttendanceStatus.approved,
                                );
                            if (!mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Attendance ${record.id} approved.',
                                ),
                              ),
                            );
                          } catch (error) {
                            if (!mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to approve attendance. $error',
                                ),
                              ),
                            );
                          }
                        }
                      : null,
                  onDecline: record.status == AttendanceStatus.pending
                      ? () async {
                          try {
                            await context
                                .read<AppState>()
                                .updateAttendanceStatus(
                                  record.id,
                                  AttendanceStatus.declined,
                                );
                            if (!mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Attendance ${record.id} declined.',
                                ),
                              ),
                            );
                          } catch (error) {
                            if (!mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to decline attendance. $error',
                                ),
                              ),
                            );
                          }
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
  final TextEditingController _totalSalaryController = TextEditingController();
  final TextEditingController _scheduledHoursController =
      TextEditingController();
  TimeOfDay? _scheduledStart;
  TimeOfDay? _approveInTime;
  String? _formError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _totalSalaryController.dispose();
    _scheduledHoursController.dispose();
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

  Future<void> _pickApproveInTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _approveInTime ?? const TimeOfDay(hour: 9, minute: 30),
    );
    if (selected != null) {
      setState(() {
        _approveInTime = selected;
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _formError = null;
    });
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_scheduledStart == null || _approveInTime == null) {
      setState(() {
        _formError = 'Scheduled start and approve in time are required.';
      });
      return;
    }
    final totalSalary = double.tryParse(_totalSalaryController.text.trim());
    if (totalSalary == null) {
      setState(() {
        _formError = 'Enter a valid total salary amount.';
      });
      return;
    }
    final scheduledHours =
        double.tryParse(_scheduledHoursController.text.trim());
    if (scheduledHours == null) {
      setState(() {
        _formError = 'Enter the scheduled working hours (e.g. 8).';
      });
      return;
    }

    try {
      setState(() {
        _isSubmitting = true;
      });
      final employee = await context.read<AppState>().addEmployee(
            id: _idController.text,
            name: _nameController.text,
            username: _usernameController.text,
            scheduledStart: _scheduledStart!,
            approveInTime: _approveInTime!,
            totalSalary: totalSalary,
            scheduledWorkingMinutes: (scheduledHours * 60).round(),
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(employee);
    } on ValidationException catch (error) {
      setState(() {
        _formError = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
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
                controller: _totalSalaryController,
                decoration:
                    const InputDecoration(labelText: 'Total salary per shift'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Total salary is required';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _scheduledHoursController,
                decoration: const InputDecoration(
                  labelText: 'Scheduled working hours',
                  helperText: 'Enter hours such as 8 or 8.5',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Scheduled working hours are required';
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
                      onPressed: _pickApproveInTime,
                      child: Text(
                        _approveInTime == null
                            ? 'Select approve in time'
                            : 'Approve in by: ${MaterialLocalizations.of(context).formatTimeOfDay(_approveInTime!)}',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Employees who check in after the approve-in time will have their attendance marked pending automatically.',
                style: theme.textTheme.bodySmall,
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
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
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
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _inTime = widget.employee.scheduledStart;
    _outTime = widget.employee.approveOutTime;
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

  Future<void> _submit() async {
    setState(() {
      _formError = null;
    });
    if (!_formKey.currentState!.validate()) {
      return;
    }
    try {
      setState(() {
        _isSubmitting = true;
      });
      final record = await context.read<AppState>().addAttendance(
            employee: widget.employee,
            date: _selectedDate,
            inTime: _inTime,
            outTime: _outTime,
            task: _taskController.text,
            designation: _designationController.text,
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(record);
    } on ValidationException catch (error) {
      setState(() {
        _formError = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
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
                'Attendance is automatically marked pending if the check-in time is later than '
                '${localizations.formatTimeOfDay(widget.employee.approveInTime)} or the checkout time is after '
                '${localizations.formatTimeOfDay(widget.employee.approveOutTime)}.',
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
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
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
            if (record.lateCheckIn || record.beyondApprovedCheckout)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (record.lateCheckIn)
                            Text(
                              'Checked in after ${localizations.formatTimeOfDay(record.approveInCutoff)} '
                              'by ${formatDuration(record.lateBy)}.',
                              style: theme.textTheme.bodySmall,
                            ),
                          if (record.beyondApprovedCheckout)
                            Text(
                              'Checked out after ${localizations.formatTimeOfDay(record.approveOutCutoff)} '
                              'by ${formatDuration(record.overtime)}.',
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
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
