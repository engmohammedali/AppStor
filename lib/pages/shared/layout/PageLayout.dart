import 'dart:convert';

import 'package:appstore/pages/cart/Mybasket.dart';
import 'package:appstore/pages/shared/models/Provider.dart';
import 'package:appstore/pages/shared/models/products_response.dart';
import 'package:appstore/pages/shared/widgets/Drawer.dart';
import 'package:appstore/pages/shared/widgets/ProductWidget.dart';
import 'package:appstore/pages/shared/widgets/Snackbar.dart';
import 'package:appstore/services/api.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:provider/provider.dart';

class PageLayout extends StatefulWidget {
  final String title;
  final Widget body;

  Function? updateProductsByCategory;
  Function? getAllProducts;
  PageLayout(
      {super.key,
      required this.title,
      required this.body,
      this.getAllProducts,
      this.updateProductsByCategory});

  @override
  State<PageLayout> createState() => _PageLayoutState();
}

class _PageLayoutState extends State<PageLayout> {
  bool isLoading = false;
  List category = [];
  bool notap = false;
  String? itemcategory;
  List<Product> products = [];

  getProductbyCategory(String namecategory) async {
    var response = await get(
        Uri.parse('https://dummyjson.com/products/category/${namecategory}'));
    if (response.statusCode == 200) {
      final productResponse =
          ProductsResponse.fromJson(jsonDecode(response.body));
      if (productResponse.products.isNotEmpty) {
        products = productResponse.products;
        return products;
      }
    }
  }

  Future getAllCategore() async {
    var response = await Api.get('products/category-list');
    if (response.statusCode == 200) {
      List list = jsonDecode(response.body);
      category = list;
    }
  }

  Future<List<Product>> getProductByKeyWord(
      BuildContext context, String keyword) async {
    final res = await get(
        Uri.parse('https://dummyjson.com/products/search?q=$keyword'));

    if (res.statusCode == 200) {
      final productResponse = ProductsResponse.fromJson(jsonDecode(res.body));

      if (productResponse.products.isNotEmpty) {
        // يمكنك إعادة القائمة المحلية بناءً على الاستجابة من الخادم هنا
        return productResponse.products;
      } else {
        // إذا لم تكن هناك نتائج، يجب إرجاع قائمة فارغة
        return [];
      }
    } else {
      ShowsnackBar(
          context, 'Failed to load products. Status code: ${res.statusCode}');
      throw Exception(
          'Failed to load products. Status code: ${res.statusCode}');
    }
  }

  @override
  void initState() {
    getAllCategore();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var provider = Provider.of<Model>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
        
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.redAccent),
        ),
        actions: [
          IconButton(
              onPressed: () {
                products = widget.getAllProducts!();
                showSearch(
                    context: context,
                    delegate: CustomSearchDelegate(
                        products: products,
                        getProductByKeyWord: getProductByKeyWord));
              },
              icon: const Icon(
                Icons.search,
              )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton(
                value: itemcategory,
                icon: Icon(Icons.menu),
                hint: Text(
                  "Chose a category",
                  style: TextStyle(fontSize: 15),
                ),
                items: category
                    .map((item) => DropdownMenuItem(
                          value: item.toString(),
                          child: Text(item.toString()),
                        ))
                    .toList(),
                onChanged: (nameCategory) async {
                  setState(() {
                    itemcategory = nameCategory.toString();
                  });
                  await getProductbyCategory(nameCategory.toString());
                  widget.updateProductsByCategory!(products);
                }),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: Stack(children: [
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: IconButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const MyBasket()));
                    },
                    icon: const Icon(
                      Icons.shopping_cart_outlined,
                      color: Color.fromARGB(255, 255, 82, 82),
                    )),
              ),
              Visibility(
                  child: Positioned(
                top: 0,
                right: 0,
                child: Visibility(
                  visible: provider.count() > 0,
                  child: Container(
                      padding: EdgeInsets.all(1),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          color: Colors.redAccent),
                      child: Text(
                        "${provider.count()}",
                        style: TextStyle(color: Colors.white),
                      )),
                ),
              ))
            ]),
          ),
        ],
      ),
      drawer: const MyDrawer(),
      body: widget.body,
    );
  }
}

class CustomSearchDelegate extends SearchDelegate {
  List<Product> products;

  final Function getProductByKeyWord;
  CustomSearchDelegate(
      {required this.getProductByKeyWord, required this.products});

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
          onPressed: () {
            query = '';
          },
          icon: const Icon(
            Icons.close,
          ))
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    IconButton(
        onPressed: () {
          close(context, null);
        },
        icon: const Icon(Icons.arrow_back));
  }

  @override
  Widget buildResults(BuildContext context) {
    return const Text("");
  }

  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      // إذا كانت الكلمة المدخلة فارغة، عرض كل المنتجات
      return Container(
        color: Colors.grey[200],
        alignment: Alignment.center,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          itemCount: products.length,
          itemBuilder: (context, index) {
            return SizedBox(
              height: 300,
              child: ProductWidget(product: products[index], isGrid: false),
            );
          },
        ),
      );
    } else {
      // إذا كان هناك كلمة مدخلة، قم ببحث المنتجات المحتملة
      List<Product> searchResults =
          products.where((element) => element.title.contains(query)).toList();

      if (searchResults.isEmpty) {
        // إذا لم يتم العثور على نتائج محلية، استخدم getProductByKeyWord
        return FutureBuilder<List<Product>>(
          future: getProductByKeyWord(context, query),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                  child:
                      Text('an error occurred ${snapshot.error.toString()}'));
            }

            List<Product> productList = snapshot.data ?? [];

            if (productList.isEmpty) {
              return Center(
                  child: Text('There are no results for your search'));
            }

            // عرض نتائج البحث بعد الحصول عليها من API
            return Container(
              color: Colors.grey[200],
              alignment: Alignment.center,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                itemCount: productList.length,
                itemBuilder: (context, index) {
                  return SizedBox(
                    height: 300,
                    child: ProductWidget(
                        product: productList[index], isGrid: false),
                  );
                },
              ),
            );
          },
        );
      } else {
        // إذا كانت هناك نتائج محلية، قم بعرضها مباشرة
        return Container(
          color: Colors.grey[200],
          alignment: Alignment.center,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            itemCount: searchResults.length,
            itemBuilder: (context, index) {
              return SizedBox(
                height: 300,
                child:
                    ProductWidget(product: searchResults[index], isGrid: false),
              );
            },
          ),
        );
      }
    }
  }
}
