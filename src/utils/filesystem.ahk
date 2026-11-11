; FileSystem：通用路径和文件操作。
class FileSystem {
    static FindOnPath(name) {
        for directory in StrSplit(EnvGet("PATH"), ";") {
            directory := Trim(directory, ' "')
            if directory == ""
                continue
            path := directory "\" name
            attributes := FileExist(path)
            if attributes && !InStr(attributes, "D")
                return path
        }
        return ""
    }
}
