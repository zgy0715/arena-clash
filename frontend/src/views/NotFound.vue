<template>
  <div class="card" style="text-align:center;padding:80px 20px">
    <div style="font-size:72px;font-weight:800;
      background:linear-gradient(135deg,#06b6d4,#8b5cf6,#ec4899);
      -webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text">
      404
    </div>
    <p style="color:#8899b4;font-size:16px;margin:16px 0 24px">页面不存在或已被移除</p>
    <el-button type="primary" @click="$router.push('/')">返回首页</el-button>
  </div>
</template>

<script setup>
import { ElButton } from 'element-plus'
</script>
