import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

// ==========================================
// 1. Model
// ==========================================
class News {
  final int? id;
  final String title;
  final String content;
  final String date;
  final String category;
  int isSaved;

  News({
    this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.category,
    this.isSaved = 0,
  });
}

// ==========================================
// 2. Local Database
// ==========================================
class DBHelper {
  static Future<Database> database() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      path.join(dbPath, 'village_news_v4.db'), // เปลี่ยนชื่อไฟล์เพื่อรีเซ็ต DB
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE news(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, content TEXT, date TEXT, category TEXT, is_saved INTEGER)',
        );

        await db.insert('news', {
          'title': 'ประกาศ: งดจ่ายน้ำประปาชั่วคราว',
          'content':
              'พรุ่งนี้เวลา 09:00 - 15:00 น. จะมีการซ่อมบำรุงท่อประปาหลักของหมู่บ้าน ขอให้ลูกบ้านทุกท่านสำรองน้ำไว้ใช้ด้วยครับ',
          'date': '14 มี.ค. 2026',
          'category': 'ทั่วไป',
          'is_saved': 0,
        });
        await db.insert('news', {
          'title': 'เตือนภัย: ระวังพายุฤดูร้อน',
          'content':
              'กรมอุตุฯ แจ้งเตือนช่วงสัปดาห์นี้จะมีพายุฝนฟ้าคะนอง ขอให้ตรวจสอบหลังคาบ้านและระมัดระวังต้นไม้ใหญ่หักโค่น',
          'date': '10 มี.ค. 2026',
          'category': 'ด่วน',
          'is_saved': 1,
        });
      },
      version: 1,
    );
  }

  static Future<void> insertNews(Map<String, dynamic> data) async {
    final db = await DBHelper.database();
    await db.insert('news', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> getData() async {
    final db = await DBHelper.database();
    return db.query('news', orderBy: "id DESC");
  }

  static Future<void> updateData(int id, int isSaved) async {
    final db = await DBHelper.database();
    await db.update(
      'news',
      {'is_saved': isSaved},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> deleteData(int id) async {
    final db = await DBHelper.database();
    await db.delete('news', where: 'id = ?', whereArgs: [id]);
  }
}

// ==========================================
// 3. Provider
// ==========================================
class NewsProvider with ChangeNotifier {
  List<News> _items = [];
  String _searchQuery = '';

  List<News> get items {
    if (_searchQuery.isEmpty) return [..._items];
    return _items
        .where(
          (news) =>
              news.title.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  List<News> get savedItems =>
      items.where((news) => news.isSaved == 1).toList();

  void search(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> fetchAndSetNews() async {
    final dataList = await DBHelper.getData();
    _items = dataList
        .map(
          (item) => News(
            id: item['id'],
            title: item['title'],
            content: item['content'],
            date: item['date'],
            category: item['category'],
            isSaved: item['is_saved'],
          ),
        )
        .toList();
    notifyListeners();
  }

  Future<void> toggleSavedStatus(int id, int currentStatus) async {
    final newStatus = currentStatus == 0 ? 1 : 0;
    await DBHelper.updateData(id, newStatus);
    await fetchAndSetNews();
  }

  Future<void> addNews(String title, String content, String category) async {
    final now = DateTime.now();
    final dateStr =
        '${now.day}/${now.month}/${now.year + 543}'; // ใช้ปี พ.ศ. ให้ดูเป็นทางการ
    await DBHelper.insertNews({
      'title': title,
      'content': content,
      'date': dateStr,
      'category': category,
      'is_saved': 0,
    });
    await fetchAndSetNews();
  }

  Future<void> deleteNews(int id) async {
    await DBHelper.deleteData(id);
    await fetchAndSetNews();
  }
}

// ==========================================
// 4. UI: หน้าจอหลัก
// ==========================================
void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (ctx) => NewsProvider())],
      child: const VillageNewsApp(),
    ),
  );
}

class VillageNewsApp extends StatelessWidget {
  const VillageNewsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ข่าวจากผู้ใหญ่บ้าน',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A),
        ), // ใช้โทนสีน้ำเงินกรมท่า ดูน่าเชื่อถือ
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        fontFamily:
            'Roboto', // ถ้ามีฟอนต์ไทยสวยๆ สามารถเปลี่ยนชื่อฟอนต์ตรงนี้ได้ครับ
        useMaterial3: true,
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Provider.of<NewsProvider>(context, listen: false).fetchAndSetNews();
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'ด่วน':
        return const Color(0xFFDC2626); // แดง
      case 'กิจกรรม':
        return const Color(0xFFD97706); // ส้ม
      default:
        return const Color(0xFF2563EB); // น้ำเงิน
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'ด่วน':
        return Icons.warning_rounded;
      case 'กิจกรรม':
        return Icons.event_available_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  void _confirmDelete(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('ยืนยันการลบ'),
          ],
        ),
        content: const Text(
          'คุณต้องการลบข่าวสารนี้ออกจากระบบใช่หรือไม่? ข้อมูลที่ลบจะไม่สามารถกู้คืนได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Provider.of<NewsProvider>(context, listen: false).deleteNews(id);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ลบข้อมูลเรียบร้อยแล้ว'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('ลบข้อมูล'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ข่าวจากผู้ใหญ่บ้าน',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text(
                "ผู้ใหญ่บ้าน",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              accountEmail: const Text("ศูนย์กระจายข่าวสารหมู่บ้าน"),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.campaign_rounded,
                  size: 40,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              decoration: BoxDecoration(color: primaryColor),
            ),
            ListTile(
              leading: Icon(Icons.home, color: primaryColor),
              title: const Text('หน้าแรก'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.info_outline, color: primaryColor),
              title: const Text('เกี่ยวกับแอป'),
              onTap: () {},
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ช่องค้นหาสไตล์โค้งมน
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาข่าวสาร...',
                prefixIcon: Icon(Icons.search, color: primaryColor),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                // ใส่เงาให้กล่องค้นหา
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
              onChanged: (val) =>
                  Provider.of<NewsProvider>(context, listen: false).search(val),
            ),
          ),
          Expanded(
            child: Consumer<NewsProvider>(
              builder: (ctx, newsProvider, child) {
                final displayList = _selectedIndex == 0
                    ? newsProvider.items
                    : newsProvider.savedItems;

                if (displayList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ไม่มีข้อมูลข่าวสาร',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: displayList.length,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemBuilder: (ctx, i) {
                    final news = displayList[i];
                    final catColor = _getCategoryColor(news.category);

                    return Card(
                      elevation: 3,
                      shadowColor: Colors.black12,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.white),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // แถบสีด้านบนการ์ด
                              Container(height: 4, color: catColor),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        // ป้ายหมวดหมู่แบบใหม่
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: catColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _getCategoryIcon(news.category),
                                                size: 14,
                                                color: catColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                news.category,
                                                style: TextStyle(
                                                  color: catColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                news.isSaved == 1
                                                    ? Icons.bookmark
                                                    : Icons.bookmark_border,
                                                color: news.isSaved == 1
                                                    ? primaryColor
                                                    : Colors.grey,
                                              ),
                                              onPressed: () => newsProvider
                                                  .toggleSavedStatus(
                                                    news.id!,
                                                    news.isSaved,
                                                  ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                              ),
                                              onPressed: () => _confirmDelete(
                                                context,
                                                news.id!,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      news.title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      news.content,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'ประกาศเมื่อ: ${news.date}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddNewsScreen()),
              ),
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_comment_rounded),
              label: const Text(
                'เพิ่มประกาศ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dynamic_feed_rounded),
              label: 'ข่าวทั้งหมด',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bookmarks_rounded),
              label: 'บันทึกไว้อ่าน',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey,
          onTap: (index) => setState(() => _selectedIndex = index),
        ),
      ),
    );
  }
}

// --- หน้าจอสำหรับป้อนข้อมูลข่าวสาร ---
class AddNewsScreen extends StatefulWidget {
  const AddNewsScreen({super.key});

  @override
  State<AddNewsScreen> createState() => _AddNewsScreenState();
}

class _AddNewsScreenState extends State<AddNewsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedCategory = 'ทั่วไป';

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      Provider.of<NewsProvider>(context, listen: false).addNews(
        _titleController.text,
        _contentController.text,
        _selectedCategory,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('ประกาศข่าวสารเรียบร้อย!'),
            ],
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'สร้างประกาศใหม่',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: Colors.white,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              Text(
                'รายละเอียดข่าวสาร',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'กรุณากรอกข้อมูลให้ครบถ้วนเพื่อแจ้งให้ลูกบ้านทราบ',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'หัวข้อข่าว',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.title_rounded, color: primaryColor),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'กรุณาใส่หัวข้อข่าว'
                    : null,
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'หมวดหมู่',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.category_rounded, color: primaryColor),
                ),
                items: ['ทั่วไป', 'ด่วน', 'กิจกรรม']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _contentController,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'เนื้อหาข่าวสาร',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'กรุณาใส่เนื้อหาข่าว'
                    : null,
              ),
              const SizedBox(height: 32),

              SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  onPressed: _saveForm,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text(
                    'บันทึกและประกาศ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
