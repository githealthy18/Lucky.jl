module Config

export FILESTORE

using Minio

const FILESTORE = MinioConfig("http://localhost:9000")

end