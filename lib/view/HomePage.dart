import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:mou/http/api/Api.dart';
import 'package:mou/item/BannerItem.dart' as bannerItem;
import 'package:mou/item/HomeGridItem.dart';
import 'package:mou/item/HomeItem.dart' as homeItem;
import 'package:mou/utils/CommonUtil.dart';
import 'package:mou/utils/NavigatorUtils.dart';
import 'package:mou/utils/Toast.dart';
import 'dart:math';
import 'package:banner_view/banner_view.dart';
import 'package:mou/http/Http.dart';
import 'package:mou/view/SearchPage.dart';

class HomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return HomeState();
  }
}

class HomeState extends State<HomePage> {
  List<homeItem.Datas> homeData = [];
  List<bannerItem.Data> bannerList = [];
  final int headerCount = 1;
  var bannerIndex = 0;
  final int pageSize = 20;
  var page = 0;

  //是否在加载
  bool isLoading = false;

  //是否有更多数据
  bool isHasNoMore = false;

  //这个key用来在不是手动下拉，而是点击某个button或其它操作时，代码直接触发下拉刷新
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  final ScrollController _scrollController =
      ScrollController(keepScrollOffset: false);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 2,
        child: Scaffold(
            appBar: AppBar(
              title: Text("首页"),
              centerTitle: true,
              actions: <Widget>[
                IconButton(
                    icon: Icon(Icons.search),
                    onPressed: () {
                      NavigatorUtils.gotoSearch(context);
                    })
              ],
            ),
            body: RefreshIndicator(
                color: Colors.green,
                child: buildCustomScrollView(),
                onRefresh: refreshHelper)));
  }

  @override
  void initState() {
    super.initState();
    getBannerList();
    getNewsListData(false);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        if (!isLoading) {
          page++;
          getNewsListData(true);
        }
      }
    });
  }

  Future<Null> refreshHelper() {
    final Completer<Null> completer = Completer<Null>();
    //清空数据
    homeData.clear();
    bannerList.clear();
    page = 0;
    getNewsListData(false, completer);
    getBannerList();
    return completer.future;
  }

  ///创建listView
  ListView buildCustomScrollView() {
    return ListView.builder(
      ///保持ListView任何情况都能滚动，解决在RefreshIndicator的兼容问题。
      physics: const AlwaysScrollableScrollPhysics(),
      key: _refreshIndicatorKey,
      itemCount: homeData.length + headerCount + 1,
      controller: _scrollController,
      itemBuilder: (context, index) {
        if (index == 0) {
          return buildBanner();
        } else {
          return getItem(index - headerCount);
        }
      },
    );
  }

  ///创建banner
  Widget buildBanner() {
    return Container(
      child: bannerList.length > 0
          ? BannerView(
              bannerList.map((bannerItem.Data item) {
                return GestureDetector(
                    onTap: () {
                      NavigatorUtils.gotoDetail(context, item.url, item.title);
                    },
                    child: Image.network(
                      item.imagePath,
                      fit: BoxFit.cover,
                    ));
              }).toList(),
              cycleRolling: false,
              autoRolling: true,
              indicatorMargin: 8.0,
              indicatorNormal: this._indicatorItem(Colors.white),
              indicatorSelected:
                  this._indicatorItem(Colors.white, selected: true),
              indicatorBuilder: (context, indicator) {
                return this._indicatorContainer(indicator);
              },
              onPageChanged: (index) {
                bannerIndex = index;
              },
            )
          : Container(),
      width: double.infinity,
      height: 200.0,
    );
  }

  ///banner指示器容器
  Widget _indicatorContainer(Widget indicator) {
    var container = Container(
      height: 40.0,
      child: Stack(
        children: <Widget>[
          Opacity(
            opacity: 0.5,
            child: Container(
              color: Colors.grey[300],
            ),
          ),
          Container(
            margin: EdgeInsets.only(right: 10.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: indicator,
            ),
          ),
          Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: EdgeInsets.only(left: 15),
                child: Text(bannerList[bannerIndex].title),
              )),
        ],
      ),
    );
    return Align(
      alignment: Alignment.bottomCenter,
      child: container,
    );
  }

  ///banner指示器view
  Widget _indicatorItem(Color color, {bool selected = false}) {
    double size = selected ? 10.0 : 6.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.all(
          Radius.circular(5.0),
        ),
      ),
    );
  }

  ///获取首页列表数据
  void getNewsListData(bool isLoadMore, [Completer completer]) async {
    if (isLoadMore) {
      setState(() => isLoading = true);
    }

    var response =
        await HttpUtil().get(Api.HOME_LIST + page.toString() + "/json");
    var item = homeItem.HomeItem.fromJson(response);
    completer?.complete();
    if (item.data.datas.length < pageSize) {
      isHasNoMore = true;
    } else {
      isHasNoMore = false;
    }
    if (isLoadMore) {
      isLoading = false;
      homeData.addAll(item.data.datas);
      setState(() {});
    } else {
      setState(() {
        homeData = item.data.datas;
      });
    }
  }

  ///获取轮播图接口
  void getBannerList() async {
    var response = await HttpUtil().get(Api.BANNER_LIST);
    var item = bannerItem.BannerItem.fromJson(response);
    bannerList = item.data;
    setState(() {});
  }

  Widget getItem(int i) {
    if (i == homeData.length) {
      if (isHasNoMore) {
        return _buildNoMoreData();
      } else {
        return _buildLoadMoreLoading();
      }
    } else {
      var item = homeData[i];
      var date =
          DateTime.fromMillisecondsSinceEpoch(item.publishTime, isUtc: true);
      return buildCardItem(item, date, i);
    }
  }

  ///"加载更多" view
  Widget _buildLoadMoreLoading() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Opacity(
          opacity: isLoading ? 1.0 : 0.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SpinKitFadingCircle(
                color: Colors.grey,
                size: 30.0,
              ),
              Padding(padding: EdgeInsets.only(left: 10)),
              Text("正在加载更多...")
            ],
          ),
        ),
      ),
    );
  }

  ///创建"没有更多"view
  Widget _buildNoMoreData() {
    return Container(
      margin: EdgeInsets.only(top: 15.0, bottom: 15.0),
      alignment: Alignment.center,
      child: Text("没有更多数据了"),
    );
  }

  ///创建卡片式view（列表的item）
  Card buildCardItem(homeItem.Datas item, DateTime date, int index) {
    return Card(
        child: InkWell(
      onTap: () {
        var url = homeData[index].link;
        var title = homeData[index].title;
        NavigatorUtils.gotoDetail(context, url, title);
      },
      child: Container(
        margin: EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 10.0),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3.0),
                      border: Border.all(color: Colors.blue)),
                  child: Text(
                    item.superChapterName,
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(left: 5.0),
                  child: Text(item.author),
                ),
                Expanded(child: Container()),
                Text(
                  "${date.year}年${date.month}月${date.day}日 ${date.hour}:${date.minute}",
                  style: TextStyle(fontSize: 12.0, color: Colors.grey),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  height: 80.0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: CommonUtil.getScreenWidth(context) - 100,
                        child: Text(
                          item.title,
                          softWrap: true, //换行
                          maxLines: 2,
                          style: TextStyle(fontSize: 16.0),
                        ),
                        margin: EdgeInsets.only(top: 10.0),
                      ),
                      Container(
                        child: Text(
                          item.superChapterName + "/" + item.author,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
                item.envelopePic.isEmpty
                    ? Container(
                        width: 60.0,
                        height: 60.0,
                      )
                    : Image.network(
                        item.envelopePic,
                        width: 60.0,
                        height: 60.0,
                        fit: BoxFit.cover,
                      ),
              ],
            ),
          ],
        ),
      ),
    ));
  }

  @override
  void dispose() {
    super.dispose();
    _scrollController.dispose();
  }
}
