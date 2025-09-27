import 'package:flutter/material.dart';
import 'database.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DM2SQL - SQLite WASM Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late MyDatabase database;
  List<Customer> customers = [];
  List<Product> products = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      database = MyDatabase();

      // 初期データをセットアップ
      await database.setupInitialData();

      // データを読み込み
      await _loadData();

    } catch (e) {
      setState(() {
        error = 'データベースの初期化に失敗しました: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final [customerList, productList] = await Future.wait([
        database.getAllCustomers(),
        database.getAllProducts(),
      ]);

      setState(() {
        customers = customerList.cast<Customer>();
        products = productList.cast<Product>();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'データの読み込みに失敗しました: $e';
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('DM2SQL - SQLite WASM Demo'),
      ),
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    error!,
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initializeDatabase,
                    child: const Text('再試行'),
                  ),
                ],
              ),
            )
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.people), text: '顧客'),
                      Tab(icon: Icon(Icons.inventory), text: '商品'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildCustomersTab(),
                        _buildProductsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadData,
        tooltip: 'データを再読み込み',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildCustomersTab() {
    if (customers.isEmpty) {
      return const Center(child: Text('顧客データがありません'));
    }

    return ListView.builder(
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        return Card(
          margin: const EdgeInsets.all(8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                customer.name.isNotEmpty ? customer.name[0] : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(customer.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📧 ${customer.email}'),
                if (customer.address != null) Text('🏠 ${customer.address}'),
                if (customer.phone != null) Text('📱 ${customer.phone}'),
                Text('📅 ${_formatDateTime(customer.createdAt)}'),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildProductsTab() {
    if (products.isEmpty) {
      return const Center(child: Text('商品データがありません'));
    }

    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          margin: const EdgeInsets.all(8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: const Icon(Icons.inventory, color: Colors.white),
            ),
            title: Text(product.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.description != null) Text(product.description!),
                Text('💰 ¥${product.price.toString()}'),
                Text('📦 在庫: ${product.stock}個'),
                Text('📅 ${_formatDateTime(product.createdAt)}'),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/'
           '${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}