# 项目协作约定

- 使用中文沟通，界面保持简洁、低饱和配色和常规字重。
- 当前仅保留待办与时历；不要恢复专注或记录模块。
- 用户已要求：每次完成修改后推送到 https://github.com/Symplatt/inch-light.git，并更新 GitHub Release。
- 本轮发布从 2.0.1 开始；以后递增语义化版本，普通修复默认递增补丁号。pubspec.yaml 的构建号必须持续递增。
- 每次发布更新 CHANGELOG.md（Keep a Changelog 分类和日期），同步 README 中的版本及功能说明。
- 发布前执行格式检查、flutter analyze 和 flutter test；标签与 pubspec.yaml 的版本必须一致。
- 验证安装包生成并上传 Release 后再报告发布成功。
- 不覆盖现有版本标签，不强推，不提交凭据、签名密钥或本机构建目录。
