# Converting between different ways of representing image data

##' Convert a pixel image to a data.frame
##'
##' This function combines the output of pixel.grid with the actual values (stored in $value)
##' 
##' @param x an image of class cimg
##' @param ... arguments passed to pixel.grid
##' @param wide if "c" or "d" return a data.frame that is wide along colour or depth (for example with rgb values along columns). The default is FALSE, with each pixel forming a separate entry. 
##' @return a data.frame
##' @author Simon Barthelme
##' @examples
##'
##' #First five pixels
##' as.data.frame(boats) %>% head(5)
##' #Wide format along colour axis
##' as.data.frame(boats,wide="c") %>% head(5)
##' @export
as.data.frame.cimg <- function (x, ...,wide=c(FALSE,"c","d"))
{
    wide <- match.arg(wide)
    if (wide=="c")
    {
        gr <- pixel.grid(R(x),...)
        cc <- channels(x) %>% do.call('cbind',.)
        cbind(gr,cc)
    }
    else if (wide=="d")
    {
        gr <- pixel.grid(frame(x,1),...)
        ff <- frames(x) %>% do.call('cbind',.)
        cbind(gr,ff)
    }
    else
    {
        gr <- pixel.grid(x, ...)
        gr$value <- c(x)
        gr
    }
}



##' Convert a cimg object to a raster object for plotting
##'
##' raster objects are used by R's base graphics for plotting. R wants hexadecimal RGB values for plotting, e.g. gray(0) yields #000000, meaning black. If you want to control precisely how numerical values are turned into colours for plotting, you need to specify a colour scale using the colourscale argument (see examples). Otherwise the default is "gray" for grayscale images, "rgb" for colour. These expect values in [0..1], so the default is to rescale the data to [0..1]. If you wish to over-ride that behaviour, set rescale=FALSE.  
##' 
##' @param x an image (of class cimg)
##' @param frames which frames to extract (in case depth > 1)
##' @param rescale rescale so that pixel values are in [0,1]? (subtract min and divide by range). default TRUE
##' @param colourscale a function that returns RGB values in hexadecimal
##' @param colorscale same as above in American spelling
##' @param ... ignored
##' @return a raster object
##' @seealso plot.cimg, rasterImage
##' @author Simon Barthelme
##' @examples
##' #A raster is a simple array of RGB values
##' as.raster(boats) %>% str
##' #By default as.raster rescales input values, so that:
##' all.equal(as.raster(boats),as.raster(boats/2)) #TRUE
##' #Setting rescale to FALSE changes that
##' try(as.raster(boats,rescale=FALSE))
##' #The above fails because the pixel values are in the wrong range
##' boats <- boats/255 #Rescale to 0..1
##' as.raster(boats,rescale=FALSE) %>% plot
##' as.raster(boats/2,rescale=FALSE) %>% plot
##' #For grayscale images, a colourmap should take a single value and
##' #return  an RGB code
##' #Example: mapping grayscale value to saturation
##' cscale <- function(v) hsv(.5,v,1)
##' grayscale(boats) %>% as.raster(colourscale=cscale) %>% plot
##' @export
as.raster.cimg <- function(x,frames,rescale=TRUE,colourscale=NULL,colorscale=NULL,...)
{
    if (is.null(colorscale) && is.null(colourscale))
    {
        colourscale <- if (spectrum(x) == 1) gray else rgb
    }
    else
    {
        if (is.null(colourscale))
        {
            colourscale <- colorscale
        }
        if (rescale)
        {
            warning("You've specified a colour scale, but rescale is set to TRUE. You may get unexpected results")
        }
    }
    im <- x
    w <- width(im)
    h <- height(im)
    if (depth(im) == 1)
    {
        if (rescale) im <- renorm(im,0,1)
        if (spectrum(im) == 1) #BW
        {
            dim(im) <- dim(im)[1:2]
            r <- im %>%  colourscale
            dim(r) <- dim(im)[2:1]
            class(r) <- "raster"
        }
        else{
            v <- channels(im) %>% lapply(as.matrix)
            r <- colourscale(v[[1]],v[[2]],v[[3]])
            dim(r) <- dim(im)[2:1]
            class(r) <- "raster"
        }
        r
    }
    else
    {
        if (missing(frames)) frames <- 1:depth(im)
        imager::frames(im,frames) %>% llply(as.raster.cimg)
    }
}

##' Convert cimg to spatstat im object
##'
##' The spatstat library uses a different format for images, which have class "im". This utility converts a cimg object to an im object. spatstat im objects are limited to 2D grayscale images, so if the image has depth or spectrum > 1 a list is returned for the separate frames or channels (or both, in which case a list of lists is returned, with frames at the higher level and channels at the lower one).
##' 
##' @param img an image of class cimg
##' @param W a spatial window (see spatstat doc). Default NULL
##' @return an object of class im, or a list of objects of class im, or a list of lists of objects of class im
##' @author Simon Barthelme
##' @seealso im, as.im
##' @export
cimg2im <- function(img,W=NULL)
    {
        
        if (requireNamespace("spatstat",quietly=TRUE))
            {
                if (depth(img) > 1)
                    {
                        l <- ilply(img,axis="z",cimg2im,W=W)
                        l
                    }
                else if (spectrum(img) > 1)
                    {
                        l <- ilply(img,axis="c",cimg2im,W=W)
                        l
                    }
                else
                    {
                        imrotate(img,90) %>% as.array %>% squeeze %>% spatstat::as.im(W=W)
                    }
            }
        else
            {
                stop("The spatstat package is required")
            }
    }

##' Convert an image in spatstat format to an image in cimg format
##'
##' as.cimg.im is an alias for the same function
##' 
##' @param img a spatstat image
##' @return a cimg image
##' @author Simon Barthelme
##' @export
im2cimg <- function(img)
    {
        if (requireNamespace("spatstat",quietly=TRUE))
            {
                spatstat::as.matrix.im(img) %>% as.cimg %>% imrotate(-90)
            }
        else
            {
                stop("The spatstat package is required")
            }
    }

as.cimg.im <- im2cimg

##' Convert to cimg object
##'
##' Imager implements various converters that turn your data into cimg objects. If you convert from a vector (which only has a length, and no dimension), either specify dimensions explicitly or some guesswork will be involved. See examples for clarifications. 
##' 
##' @param obj an object
##' @param x width
##' @param y height
##' @param z depth
##' @param cc spectrum
##' @param dim a vector of dimensions (optional, use instead of xyzcc)
##' @param ... optional arguments
##' @seealso as.cimg.array, as.cimg.function, as.cimg.data.frame
##' @export
##' @examples
##' as.cimg(1:100,x=10,y=10) #10x10, grayscale image
##' as.cimg(rep(1:100,3),x=10,y=10,cc=3) #10x10 RGB
##' as.cimg(1:100,dim=c(10,10,1,1))
##' as.cimg(1:100) #Guesses dimensions, warning is issued
##' as.cimg(rep(1:100,3)) #Guesses dimensions, warning is issued
##' @author Simon Barthelme
as.cimg <- function(obj,...) UseMethod("as.cimg")


##' @describeIn as.cimg convert numeric
##' @export
as.cimg.numeric <- function(obj,...) as.cimg.vector(obj,...)

##' @describeIn as.cimg convert logical
##' @export
as.cimg.logical <- function(obj,...) as.cimg.vector(as.numeric(obj),...)

##' @describeIn as.cimg convert double
##' @export
as.cimg.double <- function(obj,...) as.cimg.vector(obj,...)

##' @describeIn as.cimg convert vector
##' @export
as.cimg.vector <- function(obj,x=NA,y=NA,z=NA,cc=NA,dim=NULL,...)
    {
        if (!is.null(dim))
        {
            x <- dim[1];y <- dim[2];z <- dim[3];cc <- dim[4]
        }
        args <- list(x=x,y=y,z=z,cc=cc)
        if (any(!is.na(args)))
            {
                args[is.na(args)] <- 1
                d <- do.call("c",args)
                if (prod(d)==length(obj))
                    {
                        array(obj,d)%>% cimg
                    }
                else
                    {
                        stop("Dimensions are incompatible with input length")
                    }
            }
        else
            {
                l <- length(obj)
                is.whole <- function(v) isTRUE(all.equal(round(v), v))
                if (is.whole(sqrt(l)))
                    {
                        warning("Guessing input is a square 2D image")
                        d <- sqrt(l)
                        array(obj,c(d,d,1,1)) %>% cimg
                    }
                else if (is.whole(sqrt(l/3)))
                    {
                        warning("Guessing input is a square 2D RGB image")
                        d <- sqrt(l/3)
                        array(obj,c(d,d,1,3))%>% cimg
                    }
                else if (is.whole((l)^(1/3))) 
                    {
                        warning("Guessing input is a cubic 3D image")
                        d <- l^(1/3)
                        array(obj,c(d,d,d,1))%>% cimg
                    }
                else if (is.whole((l/3)^(1/3))) 
                    {
                        warning("Guessing input is a cubic 3D RGB image")
                        d <- (l/3)^(1/3)
                        array(obj,c(d,d,d,3))%>% cimg
                    }
                else
                    {
                        stop("Please provide image dimensions")
                    }
            }
    }



##' Turn an numeric array into a cimg object
##'
##' If the array has two dimensions, we assume it's a grayscale image. If it has three dimensions we assume it's a video, unless the third dimension has a depth of 3, in which case we assume it's a colour image,
##' 
##' @export
##' @param obj an array
##' @param ... ignored
##' @examples
##' as.cimg(array(1:9,c(3,3)))
##' as.cimg(array(1,c(10,10,3))) #Guesses colour image
##' as.cimg(array(1:9,c(10,10,4))) #Guesses video
as.cimg.array <- function(obj,...)
    {
        d <- dim(obj)
        if (is.logical(obj) | is.integer(obj))
            {
                obj <- obj+0.0
            }
        if (length(d)==4)
            {
                cimg(obj)
            }
        else if (length(d) == 2)
            {
                as.cimg.matrix(obj)
            }
        else if (length(d) == 3)
        {
            if (d[3] == 3)
                    {
                        warning('Assuming third dimension corresponds to colour')
                        dim(obj) <- c(d[1:2],1,d[3])
                        cimg(obj)
                    }
            else {
                warning('Assuming third dimension corresponds to time/depth')
                dim(obj) <- c(d,1)
                cimg(obj)
            }
        }
        else
            {
                stop("Array must have at most 4 dimensions ")
            }
    }

##' @export
as.array.cimg <- function(x,...) {
    class(x) <- "array"
    x
}
##' @describeIn as.cimg Convert to matrix
##' @export
as.cimg.matrix <- function(obj,...)
    {
        dim(obj) <- c(dim(obj),1,1)
        cimg(obj)
    }

##' Create an image from a data.frame
##'
##' This function is meant to be just like as.cimg.data.frame, but in reverse. Each line in the data frame must correspond to a pixel. For example, the data fame can be of the form (x,y,value) or (x,y,z,value), or (x,y,z,cc,value). The coordinates must be valid image coordinates (i.e., positive integers). 
##' 
##' @param obj a data.frame
##' @param v.name name of the variable to extract pixel values from (default "value")
##' @param dims a vector of length 4 corresponding to image dimensions. If missing, a guess will be made.
##' @param ... ignored
##' @return an object of class cimg
##' @examples
##' #Create a data.frame with columns x,y and value
##' df <- expand.grid(x=1:10,y=1:10) %>% mutate(value=x*y)
##' #Convert to cimg object (2D, grayscale image of size 10*10
##' as.cimg(df,dims=c(10,10,1,1)) %>% plot
##' @author Simon Barthelme
##' @export
as.cimg.data.frame <- function(obj,v.name="value",dims,...)
{
    nm <- names(obj) %>% tolower
    names(obj) <- nm
    if (!any(c("x","y","z","c","cc") %in% nm))
    {
        stop('input must have (x,y,value) format or similar, see help')
    }
    which.v <- (names(obj) == v.name) %>% which
    col.coord <- (names(obj) %in% names.coords) %>% which
    coords <- names(obj)[col.coord]
    if (length(which.v) == 0)
    {
        sprintf("Variable %s is missing",v.name) %>% stop
    }
    if (any(sapply(obj[,-which.v],min) <= 0))
    {
        stop('Indices must be positive')
    }
    if (missing(dims))
    {
        warning('Guessing image dimensions from maximum coordinate values')
        dims <- rep(1,4)
        for (n in coords)
        {
            dims[index.coords[[n]]] <- max(obj[[n]])
        }
    }
    im <- as.cimg(array(0,dims))
    ind <- index.coord(im,obj[,col.coord,drop=FALSE])
    im[ind] <- obj[[v.name]]
    im
}

##' @export
as.matrix.cimg <- function(x,...) {
    d <- dim(x)
    if (sum(d==1) == 2)
        {
            x <- squeeze(x)
            class(x) <- "matrix"
            x
        }
    else if (sum(d > 1) == 1)
    {
        warning("Image is one-dimensional")
        as.vector(x) %>% as.matrix
    }
    else
        {
            stop("Too many non-empty dimensions")
        }
}
