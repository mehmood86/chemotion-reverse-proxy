FROM nginx:1.21.6
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 9080
CMD ["nginx", "-g", "daemon off;"]
