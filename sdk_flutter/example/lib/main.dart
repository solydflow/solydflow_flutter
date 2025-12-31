import 'package:flutter/material.dart';
import 'package:solydflow_flutter/solydflow_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Using a test ID
  await SolydFlow.configure(
    apiKey: "sf_live_test123", 
    userID: "test_user_new_1"
  );
  runApp(const MyApp());
}

// 1. Setup Class (Does not hold state)
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      // 2. We move the UI to a separate widget so it gets a valid Context
      home: const HomePage(), 
    );
  }
}

// 3. UI Class (Holds State & Logic)
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isPro = false;
  bool isLoading = false;
  List<SolydPackage> offerings = []; 

  @override
  void initState() {
    super.initState();
    _initData();
    // _checkStatus();
  }

  Future<void> _checkStatus() async {
    bool status = await SolydFlow.getIsPro();
    if (mounted) setState(() => isPro = status);
  }

  Future<void> _initData() async {
    // 1. Check Status
    bool status = await SolydFlow.getIsPro();
    // 2. Fetch Products
    List<SolydPackage> packages = await SolydFlow.getOfferings();
    
    if (mounted) {
      setState(() {
        isPro = status;
        offerings = packages;
      });
    }
  }

  Future<void> _handlePurchase(String packageID) async {
    setState(() => isLoading = true);
    await SolydFlow.purchasePackage(context, packageID); // Pass the ID
    bool status = await SolydFlow.getIsPro(); // Check status again
    if (mounted) {
      setState(() {
        isPro = status;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SolydFlow Dynamic'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Syncing with server..."))
              );
              await _checkStatus();
            },
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // STATUS UI
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: isPro ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isPro ? Colors.green : Colors.red),
              ),
              child: Text(
                isPro ? "PRO MEMBER 💎" : "FREE USER",
                style: TextStyle(color: isPro ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(height: 40),

            // DYNAMIC PAYWALL
            if (!isPro && offerings.isEmpty)
              const CircularProgressIndicator(),

            if (!isPro && offerings.isNotEmpty) ...[
              const Text("Choose a Plan:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              // Generate Buttons for every package in DB
              ...offerings.map((pkg) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: SizedBox(
                  width: 250,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: isLoading ? null : () => _handlePurchase(pkg.identifier),
                    child: Text(
                      "${pkg.name} - ₦${pkg.amountKobo / 100}",
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              )),
            ]
          ],
        ),
      ),
    );
  }
}

//   Future<void> _checkStatus() async {
//     bool status = await SolydFlow.getIsPro();
//     if (mounted) setState(() => isPro = status);
//   }

//   Future<void> _handlePurchase() async {
//     setState(() => isLoading = true);
    
//     // NOW this context is valid because it is under MaterialApp
//     await SolydFlow.purchasePackage(context);
    
//     await _checkStatus();
//     if (mounted) setState(() => isLoading = false);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('SolydFlow Demo'), 
//         backgroundColor: Colors.grey[900],
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             onPressed: () async {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(content: Text("Syncing with server..."))
//               );
//               await _checkStatus();
//             },
//           )
//         ],
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//               decoration: BoxDecoration(
//                 color: isPro ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
//                 borderRadius: BorderRadius.circular(20),
//                 border: Border.all(color: isPro ? Colors.green : Colors.red),
//               ),
//               child: Text(
//                 isPro ? "STATUS: PRO MEMBER 💎" : "STATUS: FREE USER",
//                 style: TextStyle(
//                   color: isPro ? Colors.green : Colors.red, 
//                   fontWeight: FontWeight.bold, 
//                   fontSize: 18
//                 ),
//               ),
//             ),
//             const SizedBox(height: 40),
//             if (!isPro)
//               ElevatedButton.icon(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.orange,
//                   padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)
//                 ),
//                 onPressed: isLoading ? null : _handlePurchase,
//                 icon: const Icon(Icons.flash_on, color: Colors.black),
//                 label: Text(
//                   isLoading ? "Processing..." : "Upgrade to Pro",
//                   style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
//                 ),
//               ),
//             if (isPro)
//               const Text("🎉 You have unlocked all features!", style: TextStyle(color: Colors.grey))
//           ],
//         ),
//       ),
//     );
//   }
// }