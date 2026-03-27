App<IAppOption>({
  globalData: {},

  onLaunch() {
    // 应用初始化
  },
});

interface IAppOption {
  globalData: Record<string, unknown>;
}
